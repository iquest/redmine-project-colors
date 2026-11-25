# Adds the CSS class with the project color to the project CSS classes.
# Redmine uses these classes in the project list, in the subproject list
# and in the project list of the user page.
module ProjectColors::ProjectPatch
  def css_classes
    color_class = ProjectColors.css_class(self)
    color_class ? "#{super} #{color_class}" : super
  end
end
