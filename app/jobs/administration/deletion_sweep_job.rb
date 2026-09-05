# frozen_string_literal: true

module Administration
  class DeletionSweepJob < ApplicationJob
    class_attribute :scheduler_builder, default: -> { DeletionWorkflowScheduler.new }

    runs_on :maintenance
    system_authorization :resource_deletion_sweep,
      reason: "reconciles due, retryable and stale resource deletion workflows"

    def perform
      self.class.scheduler_builder.call.call
    end
  end
end
