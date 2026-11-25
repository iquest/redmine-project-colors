# Reads the plugin settings and finds the color of a project.
module ProjectColors
  # Accepts hexadecimal colors (#rgb, #rgba, #rrggbb, #rrggbbaa) and CSS color names.
  COLOR_FORMAT = /\A(#\h{3}|#\h{4}|#\h{6}|#\h{8}|[a-z]+)\z/i

  CSS_CLASS_PREFIX = 'project-color-'.freeze

  # Links and names of colored projects in the project lists, the activity and the time entries.
  BADGE_SELECTOR = "a[class*=\"#{CSS_CLASS_PREFIX}\"], span[class*=\"#{CSS_CLASS_PREFIX}\"], " \
                   "tr[class*=\"#{CSS_CLASS_PREFIX}\"] td.name a".freeze

  # The project jump box indents the subprojects with an inline padding of 16px for each level.
  JUMP_BOX_INDENT = 16
  JUMP_BOX_MAX_LEVEL = 5

  # The rules use !important because themes and Redmine rules with a higher specificity
  # can set the color and the padding of links. For example, "#projects-index a.icon-user"
  # removes the left padding of the projects where the user is a member.
  BADGE_STYLE = 'color: #fff !important; padding: 0.1em 0.5em !important; border-radius: 0.4em; ' \
                'text-decoration: none; display: inline-block; line-height: 1.4;'.freeze

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

    # Returns a hash of project IDs and their CSS classes with the project color.
    # The method uses one query for all projects. Views use it to prevent one query for each link.
    def css_classes_by_project_id
      id = field_id
      map = color_map
      return {} if id.nil? || map.empty?

      CustomValue.where(custom_field_id: id, customized_type: 'Project')
                 .pluck(:customized_id, :value)
                 .each_with_object({}) do |(project_id, value), classes|
        value_id = value.to_s.strip
        classes[project_id] ||= "#{CSS_CLASS_PREFIX}#{value_id}" if map.key?(value_id)
      end
    end

    # Returns the CSS rules that show colored project names as badges:
    # white text on a background in the project color.
    def stylesheet(current_project)
      map = color_map
      return nil if map.empty? || field_id.nil?

      rules = ["#{BADGE_SELECTOR} { #{BADGE_STYLE} }"]
      # Redmine 7 adds a bottom padding to the header for its absolute main menu. The A1 theme
      # shows the menu in the flow, so the padding is an empty band in the header color below the menu.
      # The rule is here and not in the theme, because a theme update replaces the theme files.
      rules << "body.theme-A1.has-main-menu #header { padding-block-end: 0; }"
      map.each do |value_id, color|
        css_class = "#{CSS_CLASS_PREFIX}#{value_id}"
        rules << "a.#{css_class}, span.#{css_class}, tr.#{css_class} td.name a { background-color: #{color} !important; }"
      end
      rules.concat(jump_box_rules(map))
      current_value_id = color_value_id(current_project, map)
      if current_value_id
        color = map[current_value_id]
        # The header of a colored project gets the project color as background, so the
        # project name in the header needs no badge. The rule uses !important because
        # themes set the header background with their own rules (for example a gradient).
        rules << "#header { background: #{color} !important; }"
        # The default and the alternate Redmine themes use this variable for the header
        # and for the menu of the responsive layout. Themes that do not use it ignore the rule.
        rules << ":root { --color-header-background: #{color}; }"
      end
      rules.join("\n")
    end

    private

    # Returns the CSS rules for the project jump box in the header.
    # Redmine builds these links without link_to_project, so the rules find them by the URL.
    def jump_box_rules(map)
      identifiers_by_value_id = Hash.new { |hash, key| hash[key] = [] }
      CustomValue.joins('INNER JOIN projects ON projects.id = custom_values.customized_id')
                 .where(custom_field_id: field_id, customized_type: 'Project')
                 .pluck(:value, 'projects.identifier')
                 .each do |value, identifier|
        value_id = value.to_s.strip
        identifiers_by_value_id[value_id] << identifier if map.key?(value_id) && identifier =~ /\A[a-z0-9_-]+\z/
      end
      return [] if identifiers_by_value_id.empty?

      all_spans = []
      rules = identifiers_by_value_id.map do |value_id, identifiers|
        spans = identifiers.flat_map do |identifier|
          ["#project-jump .drdn-items a[href$=\"/projects/#{identifier}\"] > span",
           "#project-jump .drdn-items a[href*=\"/projects/#{identifier}?\"] > span"]
        end
        all_spans.concat(spans)
        "#{spans.join(', ')} { background-color: #{map[value_id]} !important; }"
      end
      selector = ":is(#{all_spans.join(', ')})"
      rules.unshift("#{selector} { #{BADGE_STYLE} }")
      # The badge padding replaces the inline padding of the subprojects. A margin keeps the indent.
      (1..JUMP_BOX_MAX_LEVEL).each do |level|
        indent = level * JUMP_BOX_INDENT
        rules << "#{selector}[style*=\"padding-inline-start:#{indent}px\"] { margin-inline-start: #{indent}px; }"
      end
      rules
    end

    def settings
      Setting.plugin_redmine_project_colors || {}
    end
  end
end
