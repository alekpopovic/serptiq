# frozen_string_literal: true

module Projects
  class UpdateProject
    def initialize(clock: -> { Time.current }, authorization: ProjectAuthorization.new)
      @clock = clock
      @authorization = authorization
    end

    def call(actor_membership:, project_id:, name:, description:, default_locale:, time_zone:)
      project = nil
      outbox_event = Project.transaction do
        project = locked_project!(actor_membership, project_id)
        access = @authorization.authorize!(
          actor_membership: actor_membership, permission_key: "projects.update", project: project
        )
        raise ProjectTransitionInvalid.new(reason_code: "project_not_active") unless project.active?

        project.update!(
          name: name,
          description: description,
          default_locale: default_locale,
          time_zone: time_zone
        )
        ProjectAudit.record!(
          action: "project.updated",
          actor_membership_id: access.authorization.actor_membership_id,
          organization_id: project.organization_id,
          project_id: project.id,
          operation: "update"
        )
        ProjectEvent.record!(
          project: project,
          event_type: "project.updated",
          occurred_at: @clock.call,
          actor_membership_id: access.authorization.actor_membership_id
        )
      end
      ProjectEvent.enqueue(outbox_event)
      project
    end

    private

    def locked_project!(actor_membership, project_id)
      Project.lock.find_by!(id: project_id, organization_id: actor_membership&.organization_id)
    rescue ActiveRecord::RecordNotFound
      raise ProjectAccessDenied, cause: nil
    end
  end
end
