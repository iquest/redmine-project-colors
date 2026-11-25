# Adds the CSS rules with the project colors to the HTML head of each page.
class ProjectColors::Hooks < Redmine::Hook::ViewListener
  def view_layouts_base_html_head(context = {})
    css = ProjectColors.stylesheet(context[:project])
    css ? content_tag(:style, css.html_safe) : ''
  end
end
