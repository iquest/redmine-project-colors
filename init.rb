unless File.basename(File.dirname(__FILE__)) == 'redmine_project_colors'
  raise "Redmine Project Colors plugin directory should be 'redmine_project_colors' instead of '#{File.basename(File.dirname(__FILE__))}'"
end

Redmine::Plugin.register :redmine_project_colors do
  name 'Redmine Project Colors plugin'
  author 'Jan Vojtech'
  description 'Changes the color of project names according to a custom field.'
  version '2.1.0'
  url 'https://github.com/iquest/redmine-project-colors'
  author_url 'https://github.com/klasyc'
  requires_redmine version_or_higher: '4.0'

  settings default: {
    'color_field_id'    => '0',
    'color_assignments' => '',
  }, partial: 'settings/project_colors'
end

# Redmine 5.1 and later run this file in a to_prepare block.
# The plugin lib directory is an autoload path. A reference to a constant loads its file.
Project.prepend ProjectColors::ProjectPatch unless Project < ProjectColors::ProjectPatch
unless ApplicationHelper < ProjectColors::ApplicationHelperPatch
  ApplicationHelper.prepend ProjectColors::ApplicationHelperPatch
end
ProjectColors::Hooks
