require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

class ProjectColorsTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles,
           :enabled_modules, :custom_fields, :custom_values, :trackers, :projects_trackers,
           :issue_statuses, :issues, :enumerations, :time_entries, :versions, :workflows

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

  def test_link_to_project_adds_color_class
    log_user('admin', 'admin')
    get '/issues', params: { set_filter: 1, c: %w(project subject), sort: 'id' }
    assert_response :success
    assert_select "td.project a.project-color-#{@red.id}[href='/projects/ecookbook']"
    assert_select "td.project a[href='/projects/onlinestore']:not([class*='project-color-'])"
  end

  def test_link_to_project_in_group_header
    log_user('admin', 'admin')
    get '/issues', params: { set_filter: 1, group_by: 'project', c: %w(subject) }
    assert_response :success
    assert_select "tr.group span.name a.project-color-#{@red.id}"
  end

  def test_link_to_project_in_time_entries
    log_user('admin', 'admin')
    get '/time_entries', params: { set_filter: 1, c: %w(project spent_on hours) }
    assert_response :success
    assert_select "td.project a.project-color-#{@red.id}"
  end

  def test_link_to_project_keeps_other_classes_once
    get '/projects', params: { display_type: 'board' }
    assert_response :success
    link = css_select("a[href='/projects/ecookbook']").first
    classes = link['class'].split
    assert_includes classes, 'project'
    assert_equal 1, classes.count("project-color-#{@red.id}")
  end

  def test_project_name_in_my_page_timelog
    # The fixture time entries of jsmith are from 2007.
    TimeEntry.where(user_id: 2, project_id: 1).update_all(spent_on: Date.today)
    pref = User.find(2).pref
    pref.my_page_layout = { 'left' => ['timelog'], 'right' => [] }
    pref.save!
    log_user('jsmith', 'jsmith')
    get '/my/page'
    assert_response :success
    assert_select "td.subject span.project-color-#{@red.id}", text: 'eCookbook'
  end

  def test_project_name_in_activity
    log_user('admin', 'admin')
    with_settings activity_days_default: '10000' do
      get '/activity', params: { show_issues: 1 }
    end
    assert_response :success
    assert_select "dt span.project.project-color-#{@red.id}", text: 'eCookbook'
    assert_select "dt span.project:not([class*='project-color-'])", text: 'OnlineStore'
  end

  def test_project_jump_box_style
    get '/projects'
    assert_response :success
    assert_select 'style', text: %r{#project-jump \.drdn-items a\[href\$="/projects/ecookbook"\] > span.*background-color: #ff0000 !important;}
    assert_select 'style', text: /padding-inline-start:16px"\] \{ margin-inline-start: 16px; \}/
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
    assert_select "style", text: /a\.project-color-#{@red.id}, span\.project-color-#{@red.id}, tr\.project-color-#{@red.id} td\.name a \{ background-color: #ff0000 !important; \}/
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
    assert_select 'style', text: /#header \{ background: #ff0000 !important; \}/
    assert_select 'style', text: /:root \{ --color-header-background: #ff0000; \}/
    assert_select 'style', text: /current-project/, count: 0
    assert_select 'style', text: /body\.theme-A1\.has-main-menu #header \{ padding-block-end: 0; \}/
    assert_select '#header h1 .current-project', text: 'eCookbook'
  end

  def test_header_of_project_without_color
    get '/projects/subproject1'
    assert_response :success
    assert_select 'style', text: /#header \{ background/, count: 0
    assert_select 'style', text: /--color-header-background/, count: 0
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
