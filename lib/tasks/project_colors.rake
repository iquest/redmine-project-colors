# Moves the project colors from the key/value list field of plugin version 2
# to a new project custom field with the format "Color".
#
# The task reads the plugin settings "color_field_id" and "color_assignments" of version 2.
# It creates the new field with the name of the old field and copies the colors.
# Then it sets the new field in the plugin settings and deletes the old field.
#
# Usage (in the Redmine directory):
#   bin/rails redmine:project_colors:migrate_to_color_field RAILS_ENV=production
#   bin/rails redmine:project_colors:migrate_to_color_field RAILS_ENV=production KEEP_OLD_FIELD=1
#     Keeps the old field with the name "<name> (old)". Set OLD_NAME to use a different name.
namespace :redmine do
  namespace :project_colors do
    desc 'Moves the project colors from a key/value list field to a new field with the format "Color".'
    task migrate_to_color_field: :environment do
      settings = (Setting.plugin_redmine_project_colors || {}).to_h
      old_field = ProjectCustomField.find_by(id: settings['color_field_id'].to_i)
      abort 'The plugin settings have no project custom field.' unless old_field
      abort "The custom field \"#{old_field.name}\" has the format \"Color\" already." if old_field.field_format == 'color'
      abort "The custom field \"#{old_field.name}\" is not a key/value list." unless old_field.field_format == 'enumeration'

      colors = {}
      settings['color_assignments'].to_s.each_line do |line|
        value_id, color = line.split(':', 2).map(&:strip)
        next if value_id.blank?

        if value_id =~ /\A\d+\z/ && ProjectColors.normalize(color)
          colors[value_id] = ProjectColors.normalize(color)
        else
          warn "The task ignores the line \"#{line.strip}\". Only hexadecimal colors are possible."
        end
      end

      keep_old_field = ENV['KEEP_OLD_FIELD'] == '1'
      name = old_field.name
      old_name = ENV['OLD_NAME'].presence || "#{name} (old)"
      new_field = nil
      count = 0
      ActiveRecord::Base.transaction do
        # Custom field names are unique. The old field releases its name before the task creates the new field.
        old_field.update!(name: old_name)
        new_field = ProjectCustomField.new(name: name, field_format: 'color', is_required: false)
        %w(description visible editable is_filter is_for_all position).each do |attribute|
          new_field.send("#{attribute}=", old_field.send(attribute)) if new_field.respond_to?("#{attribute}=")
        end
        new_field.role_ids = old_field.role_ids
        new_field.save!

        CustomValue.where(custom_field_id: old_field.id, customized_type: 'Project').find_each do |custom_value|
          color = colors[custom_value.value.to_s.strip]
          next unless color

          CustomValue.create!(custom_field: new_field, customized_type: 'Project',
                              customized_id: custom_value.customized_id, value: color)
          count += 1
        end

        Setting.plugin_redmine_project_colors = settings.except('color_assignments')
                                                        .merge('color_field_id' => new_field.id.to_s)
        # The new field moved the old field one position down. A reload reads the new position,
        # so that the destroy does not move the new field.
        old_field.reload.destroy! unless keep_old_field
      end

      puts "The task created the custom field \"#{new_field.name}\" (ID #{new_field.id}) with the format \"Color\"."
      puts "The task copied the colors of #{count} project(s)."
      if keep_old_field
        puts "The old field has the name \"#{old_name}\" (ID #{old_field.id}). Delete it when the new colors are correct."
      else
        puts "The task deleted the old field (ID #{old_field.id})."
      end
    end
  end
end
