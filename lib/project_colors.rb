# Reads the project colors and makes the CSS rules for them.
module ProjectColors
  # The plugin stores each color as a hexadecimal color with 6 digits, for example "#2b7a3e".
  COLOR_FORMAT = /\A#\h{6}\z/

  CSS_CLASS_PREFIX = 'project-color-'.freeze

  WHITE = '#ffffff'.freeze
  BLACK = '#000000'.freeze

  # The contrast ratio of normal text in WCAG 2, level AAA. The "Adjust contrast" button changes
  # a color to this ratio. Level AA (4.5:1) needs no button: white or black text always gives at least 4.58:1.
  MIN_CONTRAST = 7.0

  # Links and names of colored projects in the project lists, the activity and the time entries.
  BADGE_SELECTOR = "a[class*=\"#{CSS_CLASS_PREFIX}\"], span[class*=\"#{CSS_CLASS_PREFIX}\"], " \
                   "tr[class*=\"#{CSS_CLASS_PREFIX}\"] td.name a".freeze

  # The project jump box indents the subprojects with an inline padding of 16px for each level.
  JUMP_BOX_INDENT = 16
  JUMP_BOX_MAX_LEVEL = 5

  # The rules use !important because themes and Redmine rules with a higher specificity
  # can set the color and the padding of links. For example, "#projects-index a.icon-user"
  # removes the left padding of the projects where the user is a member.
  BADGE_STYLE = 'padding: 0.1em 0.5em !important; border-radius: 0.4em; ' \
                'text-decoration: none; display: inline-block; line-height: 1.4;'.freeze

  # Elements of the page header that show text on the header background.
  # The main menu is in the header. Its selected tab has its own background, so the rule ignores it.
  HEADER_TEXT_SELECTOR = '#header, #header h1, #header h1 a, #quick-search label, #quick-search a, ' \
                         '#main-menu li a:not(.selected)'.freeze

  class << self
    # Returns the ID of the custom field that contains the project color, or nil.
    def field_id
      id = settings['color_field_id'].to_s.strip
      id =~ /\A\d+\z/ && id.to_i > 0 ? id.to_i : nil
    end

    # Returns the color in the format "#rrggbb", or nil if the value is not a color.
    # The method accepts upper case letters and the short format "#rgb".
    # The value must start with "#". Thus the old value IDs of a key/value list field are not colors.
    def normalize(value)
      color = value.to_s.strip.downcase
      color = "##{color[1] * 2}#{color[2] * 2}#{color[3] * 2}" if color =~ /\A#\h{3}\z/
      color =~ COLOR_FORMAT ? color : nil
    end

    # Returns the color of the project, or nil.
    def color(project)
      id = field_id
      return nil if id.nil? || project.nil? || project.new_record?

      normalize(project.custom_value_for(id)&.value)
    end

    # Returns the CSS class for the color, for example "project-color-2b7a3e".
    def css_class_for(color)
      "#{CSS_CLASS_PREFIX}#{color.delete('#')}"
    end

    # Returns the CSS class with the project color, or nil.
    def css_class(project)
      color = color(project)
      color ? css_class_for(color) : nil
    end

    # Returns a hash of project IDs and their CSS classes with the project color.
    # The method uses one query for all projects. Views use it to prevent one query for each link.
    def css_classes_by_project_id
      color_rows.to_h { |project_id, color, _identifier| [project_id, css_class_for(color)] }
    end

    # Returns the relative luminance of the color (0 for black, 1 for white), as WCAG 2 defines it.
    def luminance(color)
      red, green, blue = color.delete('#').scan(/../).map do |channel|
        value = channel.to_i(16) / 255.0
        value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
      end
      (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    end

    # Returns the WCAG 2 contrast ratio of two colors, from 1 to 21.
    def contrast_ratio(color1, color2)
      light, dark = [luminance(color1), luminance(color2)].minmax.reverse
      (light + 0.05) / (dark + 0.05)
    end

    # Returns white or black, whichever has the higher contrast on the background color.
    def text_color(background)
      contrast_ratio(background, WHITE) >= contrast_ratio(background, BLACK) ? WHITE : BLACK
    end

    # Returns true if white or black text has the minimum WCAG AAA contrast on the background color.
    def enough_contrast?(background)
      [contrast_ratio(background, WHITE), contrast_ratio(background, BLACK)].max >= MIN_CONTRAST
    end

    # Returns the WCAG 2 level of normal text for the contrast ratio: "AAA", "AA" or nil.
    def contrast_level(ratio)
      if ratio >= MIN_CONTRAST then 'AAA'
      elsif ratio >= 4.5 then 'AA'
      end
    end

    # Returns the CSS rules that show colored project names as badges:
    # text in white or black on a background in the project color.
    def stylesheet(current_project)
      rows = color_rows
      return nil if rows.empty?

      rules = ["#{BADGE_SELECTOR} { #{BADGE_STYLE} }"]
      # Redmine 7 adds a bottom padding to the header for its absolute main menu. The A1 theme
      # shows the menu in the flow, so the padding is an empty band in the header color below the menu.
      # The rule is here and not in the theme, because a theme update replaces the theme files.
      rules << "body.theme-A1.has-main-menu #header { padding-block-end: 0; }"
      rows.map { |_project_id, color, _identifier| color }.uniq.sort.each do |color|
        css_class = css_class_for(color)
        rules << "a.#{css_class}, span.#{css_class}, tr.#{css_class} td.name a " \
                 "{ background-color: #{color} !important; color: #{text_color(color)} !important; }"
      end
      rules.concat(jump_box_rules(rows))
      rules.concat(header_rules(color(current_project)))
      rules.join("\n")
    end

    private

    # Returns an array of [project ID, color, project identifier] for each project with a color.
    def color_rows
      id = field_id
      return [] if id.nil?

      CustomValue.joins('INNER JOIN projects ON projects.id = custom_values.customized_id')
                 .where(custom_field_id: id, customized_type: 'Project')
                 .pluck(:customized_id, :value, 'projects.identifier')
                 .filter_map do |project_id, value, identifier|
        color = normalize(value)
        [project_id, color, identifier] if color
      end
    end

    # Returns the CSS rules for the page header of a colored project.
    def header_rules(color)
      return [] if color.nil?

      # The header of a colored project gets the project color as background, so the
      # project name in the header needs no badge. The rule uses !important because
      # themes set the header background with their own rules (for example a gradient).
      rules = ["#header { background: #{color} !important; }"]
      # The default and the alternate Redmine themes use this variable for the header
      # and for the menu of the responsive layout. Themes that do not use it ignore the rule.
      rules << ":root { --color-header-background: #{color}; }"
      # Themes show white text in the header. A light project color needs black text.
      rules << "#{HEADER_TEXT_SELECTOR} { color: #{BLACK} !important; }" if text_color(color) == BLACK
      rules
    end

    # Returns the CSS rules for the project jump box in the header.
    # Redmine builds these links without link_to_project, so the rules find them by the URL.
    def jump_box_rules(rows)
      identifiers_by_color = Hash.new { |hash, key| hash[key] = [] }
      rows.each do |_project_id, color, identifier|
        identifiers_by_color[color] << identifier if identifier =~ /\A[a-z0-9_-]+\z/
      end
      return [] if identifiers_by_color.empty?

      all_spans = []
      rules = identifiers_by_color.sort.map do |color, identifiers|
        spans = identifiers.sort.flat_map do |identifier|
          ["#project-jump .drdn-items a[href$=\"/projects/#{identifier}\"] > span",
           "#project-jump .drdn-items a[href*=\"/projects/#{identifier}?\"] > span"]
        end
        all_spans.concat(spans)
        "#{spans.join(', ')} { background-color: #{color} !important; color: #{text_color(color)} !important; }"
      end
      selector = ":is(#{all_spans.join(', ')})"
      rules.unshift("#{selector} { #{BADGE_STYLE} }")
      # The badge padding replaces the inline padding of the subprojects. A margin keeps the indent.
      (1..JUMP_BOX_MAX_LEVEL).each do |level|
        indent = level * JUMP_BOX_INDENT
        rules << "#{selector}[style*=\"padding-inline-start:#{indent}px\"] { margin-inline-start: #{indent}px; }"
      end
      rules
    end

    def settings
      Setting.plugin_redmine_project_colors || {}
    end
  end
end
