# frozen_string_literal: true

module Authorization
  module Public
    ProjectVisibility = Data.define(:all_projects, :project_ids) do
      def initialize(all_projects:, project_ids: [])
        super(
          all_projects: !!all_projects,
          project_ids: project_ids.map { |id| id.to_s.freeze }.uniq.freeze
        )
        freeze
      end

      def all_projects?
        all_projects
      end
    end
  end
end
