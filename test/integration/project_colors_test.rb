require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

class ProjectColorsTest < Redmine::IntegrationTest
  fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles,
           :enabled_modules, :custom_fields, :custom_values, :trackers, :projects_trackers,
           :issue_statuses, :issues, :enumerations, :time_entries, :versions, :workflows

  DARK = '#2b7a3e'.freeze
  LIGHT = '#ffd43b'.freeze

  def setup
    @field = ProjectCustomField.create!(
      name: 'Color', field_format: 'color', is_for_all: true, visible: true
    )
    set_color(Project.find(1), DARK.upcase)
    set_color(Project.find(4), LIGHT)
    Setting.plugin_redmine_project_colors = { 'color_field_id' => @field.id.to_s }
  end

  def test_link_to_project_adds_color_class
    log_user('admin', 'admin')
    get '/issues', params: { set_filter: 1, c: %w(project subject), sort: 'id' }
    assert_response :success
    assert_select "td.project a.project-color-2b7a3e[href='/projects/ecookbook']"
    assert_select "td.project a[href='/projects/onlinestore']:not([class*='project-color-'])"
  end

  def test_link_to_project_in_group_header
    log_user('admin', 'admin')
    get '/issues', params: { set_filter: 1, group_by: 'project', c: %w(subject) }
    assert_response :success
    assert_select 'tr.group span.name a.project-color-2b7a3e'
  end

  def test_link_to_project_in_time_entries
    log_user('admin', 'admin')
    get '/time_entries', params: { set_filter: 1, c: %w(project spent_on hours) }
    assert_response :success
    assert_select 'td.project a.project-color-2b7a3e'
  end

  def test_link_to_project_keeps_other_classes_once
    get '/projects', params: { display_type: 'board' }
    assert_response :success
    link = css_select("a[href='/projects/ecookbook']").first
    classes = link['class'].split
    assert_includes classes, 'project'
    assert_equal 1, classes.count('project-color-2b7a3e')
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
    assert_select 'td.subject span.project-color-2b7a3e', text: 'eCookbook'
  end

  def test_project_name_in_activity
    log_user('admin', 'admin')
    with_settings activity_days_default: '10000' do
      get '/activity', params: { show_issues: 1 }
    end
    assert_response :success
    assert_select 'dt span.project.project-color-2b7a3e', text: 'eCookbook'
    assert_select "dt span.project:not([class*='project-color-'])", text: 'OnlineStore'
  end

  def test_project_jump_box_style
    get '/projects'
    assert_response :success
    assert_select 'style', text: %r{#project-jump \.drdn-items a\[href\$="/projects/ecookbook"\] > span.*background-color: #2b7a3e !important; color: #ffffff !important;}
    assert_select 'style', text: %r{#project-jump \.drdn-items a\[href\$="/projects/subproject2"\] > span.*background-color: #ffd43b !important; color: #000000 !important;}
    assert_select 'style', text: /padding-inline-start:16px"\] \{ margin-inline-start: 16px; \}/
  end

  def test_project_css_classes_contain_color_class
    assert_includes Project.find(1).css_classes.split, 'project-color-2b7a3e'
    assert_not Project.find(2).css_classes.include?('project-color-')
  end

  def test_project_list_in_board_view
    get '/projects', params: { display_type: 'board' }
    assert_response :success
    assert_select 'style', text: /a\.project-color-2b7a3e, span\.project-color-2b7a3e, tr\.project-color-2b7a3e td\.name a \{ background-color: #2b7a3e !important; color: #ffffff !important; \}/
    assert_select 'style', text: /a\.project-color-ffd43b, .* \{ background-color: #ffd43b !important; color: #000000 !important; \}/
    assert_select "a.project.project-color-2b7a3e[href='/projects/ecookbook']"
    assert_select '#header h1 .current-project', 0
  end

  def test_project_list_in_list_view
    get '/projects', params: { display_type: 'list' }
    assert_response :success
    assert_select 'tr#project-1.project-color-2b7a3e td.name a'
  end

  def test_project_overview_header
    get '/projects/ecookbook'
    assert_response :success
    assert_select 'style', text: /#header \{ background: #2b7a3e !important; \}/
    assert_select 'style', text: /:root \{ --color-header-background: #2b7a3e; \}/
    assert_select 'style', text: /#header h1 a.*color: #000000/, count: 0
    assert_select 'style', text: /current-project/, count: 0
    assert_select 'style', text: /body\.theme-A1\.has-main-menu #header \{ padding-block-end: 0; \}/
    assert_select '#header h1 .current-project', text: 'eCookbook'
  end

  def test_header_of_project_with_light_color
    get '/projects/subproject2'
    assert_response :success
    assert_select 'style', text: /#header \{ background: #ffd43b !important; \}/
    assert_select 'style', text: /#header, #header h1, #header h1 a, .* \{ color: #000000 !important; \}/
  end

  def test_header_of_project_without_color
    get '/projects/subproject1'
    assert_response :success
    assert_select 'style', text: /#header \{ background/, count: 0
    assert_select 'style', text: /--color-header-background/, count: 0
  end

  def test_no_style_when_field_is_not_specified
    Setting.plugin_redmine_project_colors = { 'color_field_id' => '' }
    get '/projects/ecookbook'
    assert_response :success
    assert_select 'style', text: /project-color/, count: 0
    assert_not Project.find(1).css_classes.include?('project-color-')
  end

  def test_assets_in_html_head
    get '/projects'
    assert_response :success
    assert_select 'link[rel=stylesheet][href*="plugin_assets/redmine_project_colors/project_colors"]'
    assert_select 'script[src*="plugin_assets/redmine_project_colors/project_colors"]'
  end

  def test_settings_page
    log_user('admin', 'admin')
    get '/settings/plugin/redmine_project_colors'
    assert_response :success
    assert_select 'select[name=?]', 'settings[color_field_id]' do
      assert_select 'option[selected][value=?]', @field.id.to_s, text: 'Color'
    end
    assert_select 'textarea', 0
  end

  def test_project_settings_show_color_picker_and_preview
    log_user('admin', 'admin')
    get '/projects/ecookbook/settings'
    assert_response :success
    assert_select '.project-colors-input' do
      assert_select 'input[type=color].project-colors-picker[value=?]:not([name])', DARK
      assert_select 'input[type=text].project-colors-code[name=?][value=?]',
                    "project[custom_field_values][#{@field.id}]", DARK
      assert_select '.project-colors-preview:not([hidden])[data-label-white=?][data-label-black=?]',
                    'White text', 'Black text' do
        assert_select '.project-colors-badge', count: 1, text: 'eCookbook'
        assert_select '.project-colors-badge[style=?]', "background-color: #{DARK}; color: #ffffff;"
        assert_select '.project-colors-text', text: 'White text'
        assert_select '.project-colors-ratio', text: '5.3:1'
        assert_select '.project-colors-level.project-colors-level-aa', text: 'AA'
      end
    end
  end

  def test_project_settings_preview_with_black_text
    log_user('admin', 'admin')
    get '/projects/subproject2/settings'
    assert_response :success
    assert_select '.project-colors-preview' do
      assert_select '.project-colors-badge[style=?]', "background-color: #{LIGHT}; color: #000000;"
      assert_select '.project-colors-text', text: 'Black text'
      assert_select '.project-colors-level.project-colors-level-aaa', text: 'AAA'
    end
  end

  def test_project_settings_show_adjust_button_for_low_contrast
    log_user('admin', 'admin')
    get '/projects/ecookbook/settings'
    assert_response :success
    assert_select '.project-colors-input[data-min-contrast="7.0"]'
    assert_select 'button[type=button].project-colors-adjust:not([hidden]):not([name])',
                  text: 'Adjust contrast'
    assert_select 'button.project-colors-adjust[title*=?]', 'at least 7:1'
  end

  def test_project_settings_hide_adjust_button_for_high_contrast
    log_user('admin', 'admin')
    get '/projects/subproject2/settings'
    assert_response :success
    assert_select 'button.project-colors-adjust[hidden]'
  end

  def test_project_settings_hide_preview_without_color
    log_user('admin', 'admin')
    get '/projects/onlinestore/settings'
    assert_response :success
    assert_select 'input.project-colors-code[value]', 0
    assert_select '.project-colors-preview[hidden]'
    assert_select 'button.project-colors-adjust[hidden]'
  end

  def test_project_settings_save_color
    log_user('admin', 'admin')
    patch '/projects/onlinestore', params: { project: { custom_field_values: { @field.id.to_s => ' #ABC ' } } }
    assert_redirected_to '/projects/onlinestore/settings'
    assert_equal '#aabbcc', Project.find(2).custom_field_value(@field)
  end

  def test_project_settings_reject_invalid_color
    log_user('admin', 'admin')
    patch '/projects/onlinestore', params: { project: { custom_field_values: { @field.id.to_s => 'red' } } }
    assert_response :success
    assert_select '#errorExplanation', text: /Color is invalid/
    assert_nil Project.find(2).custom_field_value(@field)
  end

  def test_project_overview_shows_color_value_as_swatch
    get '/projects/ecookbook'
    assert_response :success
    assert_select 'span.project-colors-swatch[style=?]', "background-color: #{DARK}; color: #ffffff;", text: DARK
  end

  private

  def set_color(project, color)
    project.custom_field_values = { @field.id.to_s => color }
    project.save!
  end
end
