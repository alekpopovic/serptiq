# frozen_string_literal: true

module Administration
  module Public
    module_function

    def plan_catalog_review(path: nil)
      BuildPlanCatalogReview.new.call(path: path)
    end

    def retire_plan_version(**attributes)
      RetirePlanVersion.new.call(**attributes)
    end

    def plan_catalog_consistency(path: nil, environment: Rails.env, at: Time.current)
      CheckPlanCatalogConsistency.new.call(path: path, environment: environment, at: at)
    end

    def request_resource_deletion(clock: -> { Time.current }, grace_period: RequestResourceDeletion::GRACE_PERIOD,
      **attributes)
      RequestResourceDeletion.new(clock: clock, grace_period: grace_period).call(**attributes)
    end

    def cancel_resource_deletion(clock: -> { Time.current }, **attributes)
      CancelResourceDeletion.new(clock: clock).call(**attributes)
    end

    def deletion_status(clock: -> { Time.current }, **attributes)
      DeletionWorkflowStatus.new(clock: clock).call(**attributes)
    end

    def execute_deletion(stage_runner: nil, clock: -> { Time.current }, **attributes)
      runner = stage_runner || DeletionStageRunner.new(object_store: DeletionWorkflowFactory.object_store)
      ExecuteDeletionWorkflow.new(stage_runner: runner, clock: clock).call(**attributes)
    end

    def schedule_due_deletions(clock: -> { Time.current }, **attributes)
      DeletionWorkflowScheduler.new(clock: clock).call(**attributes)
    end
  end
end
