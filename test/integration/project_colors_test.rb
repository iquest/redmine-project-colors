require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

class ProjectColorsTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles,
           :enabled_modules, :custom_fields, :custom_values

  def setup
    @field = ProjectCustomField.create!(
      name: 'Color', field_format: 'enumeration', is_for_all: true, visible: true
    )
    @red = @field.enumerations.create!(name: 'Red', position: 1)
    @blue = @field.enumerations.create!(name: 'Blue', position: 2)
    @project = Project.find(1)
    @project.custom_field_values = { @field.id.to_s => @red.id.to_s }
    @project.save!
    Setting.plugin_redmine_project_colors = {
      'color_field_id' => @field.id.to_s,
      'color_assignments' => "#{@red.id}: #ff0000\n#{@blue.id}: blue\nnot a line\n99999: red;}</style>\n"
    }
  end

  def test_color_map_ignores_invalid_lines
    assert_equal({ @red.id.to_s => '#ff0000', @blue.id.to_s => 'blue' }, ProjectColors.color_map)
  end

  def test_project_css_classes_contain_color_class
    assert_includes Project.find(1).css_classes.split, "project-color-#{@red.id}"
    assert_not Project.find(2).css_classes.include?('project-color-')
  end

  def test_project_list_in_board_view
    get '/projects', params: { display_type: 'board' }
    assert_response :success
    assert_select "style", text: /a\.project-color-#{@red.id}, tr\.project-color-#{@red.id} td\.name a \{ color: #ff0000; \}/
    assert_select "a.project.project-color-#{@red.id}[href='/projects/ecookbook']"
    assert_select '#header h1 .current-project', 0
  end

  def test_project_list_in_list_view
    get '/projects', params: { display_type: 'list' }
    assert_response :success
    assert_select "tr#project-1.project-color-#{@red.id} td.name a"
  end

  def test_project_overview_header
    get '/projects/ecookbook'
    assert_response :success
    assert_select 'style', text: /#header h1 \.current-project \{ color: #ff0000; \}/
    assert_select '#header h1 .current-project', text: 'eCookbook'
  end

  def test_header_of_project_without_color
    get '/projects/subproject1'
    assert_response :success
    assert_select 'style', text: /current-project/, count: 0
  end

  def test_no_style_when_field_is_not_specified
    Setting.plugin_redmine_project_colors = { 'color_field_id' => '', 'color_assignments' => "#{@red.id}: #ff0000" }
    get '/projects/ecookbook'
    assert_response :success
    assert_select 'style', text: /project-color/, count: 0
    assert_not Project.find(1).css_classes.include?('project-color-')
  end

  def test_settings_page
    log_user('admin', 'admin')
    get '/settings/plugin/redmine_project_colors'
    assert_response :success
    assert_select 'input[name=?]', 'settings[color_field_id]'
    assert_select 'textarea[name=?]', 'settings[color_assignments]'
  end
end
