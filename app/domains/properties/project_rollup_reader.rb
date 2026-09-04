# frozen_string_literal: true

module Properties
  class ProjectRollupReader
    def call(project_ids:)
      ids = project_ids.map(&:to_s).uniq
      counts = Property.active.where(project_id: ids).group(:project_id).count
      ids.index_with do |project_id|
        ProjectRollup.new(project_id: project_id, property_count: counts.fetch(project_id, 0))
      end.freeze
    end
  end
end
