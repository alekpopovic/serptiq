# frozen_string_literal: true

module Administration
  class DeletionWorkflowJob < ApplicationJob
    class_attribute :executor_builder, default: -> { DeletionWorkflowFactory.executor }

    runs_on :maintenance
    system_authorization :resource_deletion_workflow,
      reason: "executes one explicit tenant-bound deletion workflow after its retention hold"

    def perform(organization_id:, workflow_id:)
      self.class.executor_builder.call.call(
        organization_id: organization_id,
        workflow_id: workflow_id
      )
    end
  end
end
