require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'rake'

class MigrateToColorFieldTaskTest < ActiveSupport::TestCase
  fixtures :projects, :custom_fields, :custom_values

  def setup
    Rails.application.load_tasks unless Rake::Task.task_defined?('redmine:project_colors:migrate_to_color_field')
    @task = Rake::Task['redmine:project_colors:migrate_to_color_field']
    @task.reenable

    @old_field = ProjectCustomField.create!(name: 'Barva', field_format: 'enumeration', is_for_all: true, visible: true)
    @green = @old_field.enumerations.create!(name: 'Zelena', position: 1)
    @red = @old_field.enumerations.create!(name: 'Cervena', position: 2)
    @gray = @old_field.enumerations.create!(name: 'Seda', position: 3)
    set_value(Project.find(1), @green)
    set_value(Project.find(2), @red)
    set_value(Project.find(3), @gray)
    Setting.plugin_redmine_project_colors = {
      'color_field_id' => @old_field.id.to_s,
      'color_assignments' => "#{@green.id}: #2B7A3E\n#{@red.id}: #c92a2a\n#{@gray.id}: gray\n"
    }
  end

  def test_task_moves_colors_to_new_field_and_deletes_old_field
    position = @old_field.position
    _out, err = capture_io { @task.invoke }

    new_field = ProjectCustomField.find_by!(name: 'Barva')
    assert_equal 'color', new_field.field_format
    assert new_field.is_for_all
    assert_equal position, new_field.position
    assert_not CustomField.exists?(@old_field.id)
    assert_not CustomValue.exists?(custom_field_id: @old_field.id)
    assert_equal '#2b7a3e', Project.find(1).custom_field_value(new_field)
    assert_equal '#c92a2a', Project.find(2).custom_field_value(new_field)
    assert_nil Project.find(3).custom_field_value(new_field)
    assert_match(/gray/, err)
    assert_equal({ 'color_field_id' => new_field.id.to_s }, Setting.plugin_redmine_project_colors.to_h)
  end

  def test_task_keeps_old_field
    ENV['KEEP_OLD_FIELD'] = '1'
    capture_io { @task.invoke }

    assert_equal 'Barva (old)', @old_field.reload.name
    assert_equal 'color', ProjectCustomField.find_by!(name: 'Barva').field_format
  ensure
    ENV.delete('KEEP_OLD_FIELD')
  end

  private

  def set_value(project, value)
    project.custom_field_values = { @old_field.id.to_s => value.id.to_s }
    project.save!
  end
end
