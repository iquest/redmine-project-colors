# Adds the CSS class with the project color to each project link.
# Redmine uses link_to_project in the issue lists, the time entry lists,
# the group headers of grouped lists, the Gantt chart, the news and the header.
module ProjectColors::ApplicationHelperPatch
  def link_to_project(project, options = {}, html_options = nil)
    color_class = project_colors_css_class(project)
    return super if color_class.nil?

    html_options = (html_options || {}).to_h.symbolize_keys
    classes = html_options[:class].to_s.split
    html_options[:class] = (classes | [color_class]).join(' ')
    super(project, options, html_options)
  end

  # Returns the project name in a span with the project color class.
  # Returns the escaped project name if the project has no color.
  # The views of the plugin use it where Redmine shows the project name without a link.
  def project_colors_name_tag(project)
    color_class = project_colors_css_class(project)
    return h(project.to_s) if color_class.nil?

    content_tag(:span, project.to_s, class: color_class)
  end

  private

  # Reads the colors of all projects once for each view.
  def project_colors_css_class(project)
    return nil unless project.is_a?(Project)

    @project_colors_css_classes ||= ProjectColors.css_classes_by_project_id
    @project_colors_css_classes[project.id]
  end
end
