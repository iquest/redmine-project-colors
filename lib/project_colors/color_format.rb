# Adds the custom field format "Color" for projects.
# The field stores a hexadecimal color ("#rrggbb"). The edit form shows a color picker,
# a text field for the hexadecimal code and a preview of the badge with white and black text.
class ProjectColors::ColorFormat < Redmine::FieldFormat::StringFormat
  add 'color'

  self.customized_class_names = %w(Project)
  self.form_partial = nil
  self.searchable_supported = false

  def label
    'label_project_colors_color'
  end

  # Stores the color in the format "#rrggbb". The method keeps an invalid value,
  # so that the validation shows an error.
  def set_custom_field_value(custom_field, custom_field_value, value)
    stored = super
    stored.is_a?(String) ? (ProjectColors.normalize(stored) || stored.strip) : stored
  end

  def validate_single_value(custom_field, value, customized = nil)
    errors = super
    errors << ::I18n.t('activerecord.errors.messages.invalid') unless value.to_s =~ ProjectColors::COLOR_FORMAT
    errors
  end

  def formatted_value(view, custom_field, value, customized = nil, html = false)
    color = ProjectColors.normalize(value)
    return value.to_s unless html && color

    view.content_tag(:span, color, class: 'project-colors-swatch',
                                   style: "background-color: #{color}; color: #{ProjectColors.text_color(color)};")
  end

  def edit_tag(view, tag_id, tag_name, custom_value, options = {})
    color = ProjectColors.normalize(custom_value.value)
    project = custom_value.customized
    sample = project.respond_to?(:name) && project.name.present? ? project.name : ::I18n.t(:label_project)

    picker = view.color_field_tag(nil, color || ProjectColors::BLACK,
                                  id: nil, class: 'project-colors-picker',
                                  title: ::I18n.t(:label_project_colors_pick))
    field = view.text_field_tag(tag_name, custom_value.value,
                                options.merge(id: tag_id, size: 8, maxlength: 7,
                                              placeholder: '#rrggbb', class: "#{options[:class]} project-colors-code"))
    view.content_tag(:span, class: 'project-colors-input', data: { min_contrast: ProjectColors::MIN_CONTRAST }) do
      picker + field + adjust_button(view, color) + preview(view, color, sample)
    end
  end

  private

  # Shows a button that changes the lightness of the color until the text has the minimum contrast.
  # The plugin shows the button only for a color with too low contrast. The JavaScript of the plugin changes the color.
  def adjust_button(view, color)
    view.button_tag(::I18n.t(:button_project_colors_adjust_contrast),
                    type: 'button', name: nil, class: 'project-colors-adjust',
                    title: ::I18n.t(:text_project_colors_adjust_contrast, ratio: format('%g', ProjectColors::MIN_CONTRAST)),
                    hidden: color.nil? || ProjectColors.enough_contrast?(color))
  end

  # Shows the badge with the text color that the plugin uses (white or black), the contrast ratio
  # and the WCAG level. The JavaScript of the plugin updates the preview. It reads the labels
  # from the data attributes.
  def preview(view, color, sample)
    text = color && ProjectColors.text_color(color)
    ratio = color && ProjectColors.contrast_ratio(color, text)
    level = ratio && ProjectColors.contrast_level(ratio)
    labels = { label_white: ::I18n.t(:label_project_colors_white_text),
               label_black: ::I18n.t(:label_project_colors_black_text) }
    text_label = if text.nil? then ''
                 elsif text == ProjectColors::WHITE then labels[:label_white]
                 else labels[:label_black]
                 end

    badge = view.content_tag(:span, sample, class: 'project-colors-badge',
                                            style: color ? "background-color: #{color}; color: #{text};" : nil)
    info = view.content_tag(:span, class: 'project-colors-info') do
      view.safe_join([
        view.content_tag(:span, text_label, class: 'project-colors-text'),
        ' · ',
        view.content_tag(:span, ratio ? format('%.1f:1', ratio) : '', class: 'project-colors-ratio'),
        ' ',
        view.content_tag(:span, level.to_s, class: "project-colors-level project-colors-level-#{level.to_s.downcase}")
      ])
    end
    view.content_tag(:span, badge + info, class: 'project-colors-preview', hidden: color.nil?, data: labels)
  end
end
