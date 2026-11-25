# Shows the project names in the "Spent time" block of My page with the project color.
# Redmine shows these names without a link, so the plugin uses its own copy of the partial.
# The copy is not in app/views/my/blocks, because Redmine adds each partial there as a new block.
module ProjectColors::MyHelperPatch
  TIMELOG_PARTIAL = 'my/blocks/timelog'.freeze

  def render(options = {}, *args, &block)
    if options.is_a?(Hash) && options[:partial] == TIMELOG_PARTIAL
      options = options.merge(partial: 'project_colors/timelog')
    end
    super
  end
end
