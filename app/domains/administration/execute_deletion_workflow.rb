# frozen_string_literal: true

module Administration
  class ExecuteDeletionWorkflow
    LEASE_PERIOD = 5.minutes
    RETRY_DELAY = 15.minutes

    Claim = Data.define(:workflow, :stage_execution, :lease_token)

    def initialize(stage_runner:, clock: -> { Time.current }, token_generator: -> { SecureRandom.uuid })
      @stage_runner = stage_runner
      @clock = clock
      @token_generator = token_generator
    end

    def call(organization_id:, workflow_id:)
      loop do
        claim = claim_next_stage(organization_id, workflow_id)
        return workflow(organization_id, workflow_id) unless claim

        begin
          result = @stage_runner.call(
            workflow: claim.workflow,
            stage: claim.stage_execution.stage,
            cursor: claim.stage_execution.cursor
          )
          result.completed? ? complete_stage(claim) : defer_stage(claim, result.cursor)
          return workflow(organization_id, workflow_id) unless result.completed?
        rescue StandardError => error
          fail_stage(claim, error_category(error))
          raise
        end
      end
    end

    private

    def claim_next_stage(organization_id, workflow_id)
      DeletionWorkflow.transaction do
        workflow = DeletionWorkflow.lock.find_by(
          id: workflow_id, organization_id: organization_id
        )
        raise Shared::Public::SecurityRejectedJobError, "deletion workflow tenant mismatch" unless workflow
        return if workflow.completed? || workflow.canceled?

        now = @clock.call
        return if workflow.holding? && workflow.hold_until > now
        return if workflow.retryable? && workflow.next_attempt_at > now
        return if workflow.running? && workflow.lease_expires_at > now

        stage = workflow.stage_executions.where.not(state: "completed").order(:position).first
        unless stage
          finish_workflow!(workflow, now)
          return
        end

        lease_token = @token_generator.call
        workflow.update!(
          state: "running",
          current_stage: stage.stage,
          started_at: workflow.started_at || now,
          next_attempt_at: nil,
          last_error_category: nil,
          lease_token: lease_token,
          lease_expires_at: now + LEASE_PERIOD,
          attempt_count: workflow.attempt_count + 1
        )
        stage.update!(
          state: "running",
          started_at: stage.started_at || now,
          last_error_category: nil,
          attempt_count: stage.attempt_count + 1
        )
        Claim.new(workflow: workflow, stage_execution: stage, lease_token: lease_token)
      end
    end

    def complete_stage(claim)
      update_claim(claim) do |workflow, stage, now|
        stage.update!(state: "completed", completed_at: now, last_error_category: nil, cursor: nil)
        if stage.position == DeletionWorkflow::STAGES.length - 1
          finish_workflow!(workflow, now)
        else
          workflow.update!(
            state: "retryable",
            next_attempt_at: now,
            last_error_category: "stage_ready",
            lease_token: nil,
            lease_expires_at: nil
          )
        end
      end
    end

    def defer_stage(claim, cursor)
      update_claim(claim) do |workflow, stage, now|
        stage.update!(state: "retryable", last_error_category: "stage_incomplete", cursor: cursor)
        workflow.update!(
          state: "retryable",
          next_attempt_at: now + RETRY_DELAY,
          last_error_category: "stage_incomplete",
          lease_token: nil,
          lease_expires_at: nil
        )
      end
    end

    def fail_stage(claim, category)
      update_claim(claim) do |workflow, stage, now|
        stage.update!(state: "retryable", last_error_category: category)
        workflow.update!(
          state: "retryable",
          next_attempt_at: now + RETRY_DELAY,
          last_error_category: category,
          lease_token: nil,
          lease_expires_at: nil
        )
      end
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def update_claim(claim)
      DeletionWorkflow.transaction do
        workflow = DeletionWorkflow.lock.find_by!(
          id: claim.workflow.id,
          organization_id: claim.workflow.organization_id,
          lease_token: claim.lease_token,
          state: "running"
        )
        stage = workflow.stage_executions.lock.find(claim.stage_execution.id)
        yield workflow, stage, @clock.call
      end
    end

    def finish_workflow!(workflow, now)
      workflow.update!(
        state: "completed",
        current_stage: "aggregate_records",
        completed_at: now,
        next_attempt_at: nil,
        last_error_category: nil,
        lease_token: nil,
        lease_expires_at: nil
      )
      Auditing::Public.record!(
        organization_id: workflow.organization_id,
        action: "data.deletion_completed",
        target_type: workflow.target_type,
        target_id: workflow.target_id,
        result: "succeeded",
        metadata: { operation: "retention_deletion" }
      )
    end

    def workflow(organization_id, workflow_id)
      DeletionWorkflow.find_by(id: workflow_id, organization_id: organization_id)
    end

    def error_category(error)
      category = error.class.respond_to?(:error_category) && error.class.error_category
      value = category.presence || "unexpected_failure"
      value.to_s.gsub(/[^a-z0-9_]/, "_").first(64)
    end
  end
end
