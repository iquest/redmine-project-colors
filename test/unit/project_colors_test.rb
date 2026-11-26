require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

class ProjectColorsUnitTest < ActiveSupport::TestCase
  def test_normalize
    assert_equal '#2b7a3e', ProjectColors.normalize(' #2B7A3E ')
    assert_equal '#aabbcc', ProjectColors.normalize('#abc')
    assert_nil ProjectColors.normalize('2b7a3e')
    assert_nil ProjectColors.normalize('123')
    assert_nil ProjectColors.normalize('red')
    assert_nil ProjectColors.normalize('#2b7a3g')
    assert_nil ProjectColors.normalize('#2b7a3e;}')
    assert_nil ProjectColors.normalize(nil)
  end

  def test_contrast_ratio
    assert_in_delta 21.0, ProjectColors.contrast_ratio('#000000', '#ffffff'), 0.01
    assert_in_delta 21.0, ProjectColors.contrast_ratio('#ffffff', '#000000'), 0.01
    assert_in_delta 1.0, ProjectColors.contrast_ratio('#777777', '#777777'), 0.01
    assert_in_delta 4.48, ProjectColors.contrast_ratio('#777777', '#ffffff'), 0.01
  end

  def test_text_color
    assert_equal '#ffffff', ProjectColors.text_color('#2b7a3e')
    assert_equal '#ffffff', ProjectColors.text_color('#1c3d72')
    assert_equal '#000000', ProjectColors.text_color('#ffd43b')
    assert_equal '#000000', ProjectColors.text_color('#ffffff')
  end

  def test_enough_contrast
    # White or black text always has at least 4.58:1. The plugin checks the AAA level (7:1).
    assert ProjectColors.enough_contrast?('#1c3d72')
    assert ProjectColors.enough_contrast?('#ffd43b')
    assert_not ProjectColors.enough_contrast?('#2b7a3e')
    assert_not ProjectColors.enough_contrast?('#c85a00')
  end

  def test_contrast_level
    assert_equal 'AAA', ProjectColors.contrast_level(7.0)
    assert_equal 'AA', ProjectColors.contrast_level(6.99)
    assert_equal 'AA', ProjectColors.contrast_level(4.5)
    assert_nil ProjectColors.contrast_level(4.49)
  end

  def test_color_format_is_only_for_projects
    assert_includes Redmine::FieldFormat.formats_for_custom_field_class(Project).map(&:name), 'color'
    assert_not_includes Redmine::FieldFormat.formats_for_custom_field_class(Issue).map(&:name), 'color'
  end
end
