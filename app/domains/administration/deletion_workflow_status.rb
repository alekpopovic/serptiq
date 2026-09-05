# frozen_string_literal: true

module Administration
  class DeletionWorkflowStatus
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, target_type:, target_id:)
      workflow = DeletionWorkflow.where(
        organization_id: organization_id,
        target_type: target_type,
        target_id: target_id
      ).order(requested_at: :desc).first
      return unless workflow

      DeletionStatus.new(
        state: workflow.state,
        hold_until: workflow.hold_until,
        current_stage: workflow.current_stage,
        cancelable: workflow.cancelable?(at: @clock.call),
        last_error_category: workflow.last_error_category
      )
    end
  end
end
