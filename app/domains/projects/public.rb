# frozen_string_literal: true

module Projects
  module Public
    module_function

    def create_project(clock: -> { Time.current }, **attributes)
      CreateProject.new(clock: clock).call(**attributes)
    end

    def update_project(clock: -> { Time.current }, **attributes)
      UpdateProject.new(clock: clock).call(**attributes)
    end

    def transition_project(clock: -> { Time.current }, **attributes)
      TransitionProject.new(clock: clock).call(**attributes)
    end

    def project_page(read_models: ProjectOperationalReadModels.new, **attributes)
      ProjectDirectory.new(read_models: read_models).page(**attributes)
    end

    def project_details(read_models: ProjectOperationalReadModels.new, **attributes)
      ProjectDirectory.new(read_models: read_models).find(**attributes)
    end

    def reference(organization_id:, project_id:)
      project = Project.find_by(id: project_id, organization_id: organization_id)
      return unless project

      ProjectReference.new(
        id: project.id, organization_id: project.organization_id, status: project.status
      )
    end
  end
end
