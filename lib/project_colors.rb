# Reads the plugin settings and finds the color of a project.
module ProjectColors
  # Accepts hexadecimal colors (#rgb, #rgba, #rrggbb, #rrggbbaa) and CSS color names.
  COLOR_FORMAT = /\A(#\h{3}|#\h{4}|#\h{6}|#\h{8}|[a-z]+)\z/i

  CSS_CLASS_PREFIX = 'project-color-'.freeze

  class << self
    # Returns the ID of the custom field that contains the project color, or nil.
    def field_id
      id = settings['color_field_id'].to_s.strip
      id =~ /\A\d+\z/ && id.to_i > 0 ? id.to_i : nil
    end

    # Returns a hash of custom field value IDs (strings) and their colors.
    # The method ignores lines that do not have the format "value_id: color".
    def color_map
      map = {}
      settings['color_assignments'].to_s.each_line do |line|
        value_id, color = line.split(':', 2).map(&:strip)
        next unless value_id =~ /\A\d+\z/ && color =~ COLOR_FORMAT

        map[value_id] = color
      end
      map
    end

    # Returns the custom field value ID of the project if it has a color, or nil.
    def color_value_id(project, map = color_map)
      id = field_id
      return nil if id.nil? || project.nil? || project.new_record?

      value_id = project.custom_value_for(id)&.value.to_s.strip
      map.key?(value_id) ? value_id : nil
    end

    # Returns the CSS class with the project color, or nil.
    def css_class(project)
      value_id = color_value_id(project)
      value_id ? "#{CSS_CLASS_PREFIX}#{value_id}" : nil
    end

    # Returns the CSS rules for all colors and for the header of the current project.
    def stylesheet(current_project)
      map = color_map
      return nil if map.empty? || field_id.nil?

      rules = map.map do |value_id, color|
        css_class = "#{CSS_CLASS_PREFIX}#{value_id}"
        "a.#{css_class}, tr.#{css_class} td.name a { color: #{color}; }"
      end
      current_value_id = color_value_id(current_project, map)
      if current_value_id
        rules << "#header h1 .current-project { color: #{map[current_value_id]}; }"
      end
      rules.join("\n")
    end

    private

    def settings
      Setting.plugin_redmine_project_colors || {}
    end
  end
end
