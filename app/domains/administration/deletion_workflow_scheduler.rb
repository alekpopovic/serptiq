# frozen_string_literal: true

module Administration
  class DeletionWorkflowScheduler
    BATCH_SIZE = 200

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(limit: BATCH_SIZE)
      now = @clock.call
      ids = DeletionWorkflow.where(
        "(state = 'holding' AND hold_until <= :now) OR " \
          "(state = 'retryable' AND next_attempt_at <= :now) OR " \
          "(state = 'running' AND lease_expires_at <= :now)",
        now: now
      ).order(:hold_until, :id).limit(Integer(limit).clamp(1, BATCH_SIZE)).pluck(:organization_id, :id)
      ids.each do |organization_id, workflow_id|
        DeletionWorkflowJob.perform_later(
          organization_id: organization_id,
          workflow_id: workflow_id
        )
      end
      ids.length
    end
  end
end
