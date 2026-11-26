# Adds the plugin assets and the CSS rules with the project colors to the HTML head of each page.
class ProjectColors::Hooks < Redmine::Hook::ViewListener
  def view_layouts_base_html_head(context = {})
    tags = [stylesheet_link_tag('project_colors', plugin: 'redmine_project_colors'),
            javascript_include_tag('project_colors', plugin: 'redmine_project_colors')]
    css = ProjectColors.stylesheet(context[:project])
    tags << content_tag(:style, css.html_safe) if css
    safe_join(tags, "\n")
  end
end
