# frozen_string_literal: true

module Projects
  class DeleteForLifecycle
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, project_id:, deletion_workflow_id:)
      project = Project.find_by(
        id: project_id,
        organization_id: organization_id,
        status: "pending_deletion",
        deletion_workflow_id: deletion_workflow_id
      )
      raise ProjectAccessDenied unless project

      now = @clock.call
      Auditing::Public.record_target_tombstone!(
        organization_id: organization_id,
        deletion_workflow_id: deletion_workflow_id,
        target_type: "Project",
        target_id: project.id,
        project_id: project.id,
        deleted_at: now
      )
      Auditing::Public.record!(
        organization_id: organization_id,
        action: "project.deleted",
        target_type: "Project",
        target_id: project.id,
        result: "succeeded",
        metadata: { operation: "retention_deletion" },
        occurred_at: now
      )
      event = ProjectEvent.record!(
        project: project,
        event_type: "project.deleted",
        occurred_at: now,
        actor_membership_id: nil
      )
      Project.where(id: project.id, organization_id: organization_id).delete_all
      ProjectEvent.enqueue(event)
      true
    end
  end
end
