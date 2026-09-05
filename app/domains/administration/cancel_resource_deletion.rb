# frozen_string_literal: true

module Administration
  class CancelResourceDeletion
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(actor_membership:, target_type:, project_id:, property_id: nil)
      now = @clock.call
      DeletionWorkflow.transaction do
        workflow = DeletionWorkflow.active.lock.find_by(
          organization_id: actor_membership&.organization_id,
          target_type: target_type,
          target_id: target_type == "Project" ? project_id : property_id
        )
        raise deletion_error(target_type) unless workflow&.cancelable?(at: now)

        transition_target!(actor_membership, workflow)
        workflow.update!(state: "canceled", canceled_at: now)
        record_cancellation(workflow, actor_membership)
        workflow
      end
    end

    private

    def transition_target!(actor_membership, workflow)
      attributes = {
        actor_membership: actor_membership,
        project_id: workflow.project_id,
        operation: "cancel_deletion",
        deletion_workflow_id: workflow.id,
        clock: @clock
      }
      if workflow.target_type == "Project"
        Projects::Public.transition_project(**attributes)
      else
        Properties::Public.transition_property(**attributes, property_id: workflow.property_id)
      end
    end

    def record_cancellation(workflow, actor_membership)
      Auditing::Public.record!(
        organization_id: workflow.organization_id,
        actor_membership_id: actor_membership.id,
        action: "data.deletion_canceled",
        target_type: workflow.target_type,
        target_id: workflow.target_id,
        result: "succeeded",
        metadata: { operation: "cancel_deletion" }
      )
    end

    def deletion_error(target_type)
      DeletionConflict.new(reason_code: "deletion_not_cancelable")
    end
  end
end
