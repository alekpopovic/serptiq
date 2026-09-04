# frozen_string_literal: true

module Projects
  class ProjectOperationalReadModels
    def call(project_ids:)
      project_ids.index_with do |project_id|
        ProjectOperationalSnapshot.new(project_id: project_id)
      end.freeze
    end
  end
end
