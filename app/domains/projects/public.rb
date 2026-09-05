# frozen_string_literal: true

module Projects
  module Public
    module_function

    def create_project(clock: -> { Time.current }, id_generator: nil, release_key_generator: nil,
      **attributes)
      options = { clock: clock }
      options[:id_generator] = id_generator if id_generator
      options[:release_key_generator] = release_key_generator if release_key_generator
      CreateProject.new(**options).call(**attributes)
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

    def build_dashboard(**attributes)
      BuildProjectDashboard.new.call(**attributes)
    end

    def reference(organization_id:, project_id:)
      project = Project.find_by(id: project_id, organization_id: organization_id)
      return unless project

      ProjectReference.new(
        id: project.id, organization_id: project.organization_id, status: project.status
      )
    end

    def active_count(organization_id:)
      Project.active.where(organization_id: organization_id).count
    end

    def cancellation_requested?(organization_id:, project_id:, work_started_at:)
      project = Project.find_by(id: project_id, organization_id: organization_id)
      project.nil? || project.cancellation_requested_for?(work_started_at)
    end

    def delete_for_lifecycle!(clock: -> { Time.current }, **attributes)
      DeleteForLifecycle.new(clock: clock).call(**attributes)
    end

    def normalize_slug(value)
      ProjectSlug.call(value)
    end

    def valid_slug?(value)
      Project::SLUG_PATTERN.match?(value.to_s)
    end
  end
end
