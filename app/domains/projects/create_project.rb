# frozen_string_literal: true

module Projects
  class CreateProject
    def initialize(clock: -> { Time.current }, id_generator: -> { SecureRandom.uuid },
      release_key_generator: -> { "prj_#{SecureRandom.hex(16)}" }, authorization: ProjectAuthorization.new,
      limit: ProjectLimit.new)
      @clock = clock
      @id_generator = id_generator
      @release_key_generator = release_key_generator
      @authorization = authorization
      @limit = limit
    end

    def call(actor_membership:, name:, slug:, description: "", default_locale: "en", time_zone: "UTC")
      now = @clock.call
      project = nil
      outbox_event = Project.transaction do
        access = @authorization.authorize!(
          actor_membership: actor_membership, permission_key: "projects.create"
        )
        organization_id = access.authorization.organization_id
        @limit.lock_and_check!(organization_id: organization_id, at: now)
        project_id = @id_generator.call
        Authorization::Public.register_scope(
          organization_id: organization_id,
          scope_type: "Project",
          scope_id: project_id,
          status: "active"
        )
        project = Project.create!(
          id: project_id,
          organization_id: organization_id,
          slug: slug,
          name: name,
          description: description,
          status: "active",
          default_locale: default_locale,
          time_zone: time_zone,
          external_release_key: @release_key_generator.call,
          authorization_scope_type: "Project"
        )
        ProjectAudit.record!(
          action: "project.created",
          actor_membership_id: access.authorization.actor_membership_id,
          organization_id: organization_id,
          project_id: project.id,
          operation: "create"
        )
        ProjectEvent.record!(
          project: project,
          event_type: "project.created",
          occurred_at: now,
          actor_membership_id: access.authorization.actor_membership_id
        )
      end
      ProjectEvent.enqueue(outbox_event)
      project
    end
  end
end
