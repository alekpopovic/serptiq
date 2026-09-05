# frozen_string_literal: true

module Administration
  class DeletionStageRunner
    def initialize(object_store:)
      @object_store = object_store
    end

    def call(workflow:, stage:, cursor: nil)
      case stage
      when "cancel_active_work" then ensure_cancellation_signal!(workflow)
      when "integrations" then integrations(workflow)
      when "scans_and_findings" then delete_scan_inputs(workflow)
      when "reports" then DeletionStageResult.complete
      when "object_artifacts" then delete_objects(workflow, cursor)
      when "api_keys_and_webhooks" then DeletionStageResult.complete
      when "aggregate_records" then delete_aggregate(workflow)
      else raise ArgumentError, "unknown deletion stage"
      end
    end

    private

    def ensure_cancellation_signal!(workflow)
      canceled = if workflow.target_type == "Project"
        Projects::Public.cancellation_requested?(
          organization_id: workflow.organization_id,
          project_id: workflow.project_id,
          work_started_at: workflow.requested_at
        )
      else
        Properties::Public.cancellation_requested?(
          organization_id: workflow.organization_id,
          project_id: workflow.project_id,
          property_id: workflow.property_id,
          work_started_at: workflow.requested_at
        )
      end
      raise Shared::Public::CanceledJobError, "resource cancellation signal is unavailable" unless canceled

      DeletionStageResult.complete
    end

    def integrations(workflow)
      Integrations::Public.prepare_resource_deletion(
        organization_id: workflow.organization_id,
        project_id: workflow.project_id,
        property_id: workflow.property_id
      )
      DeletionStageResult.complete
    end

    def delete_scan_inputs(workflow)
      transactionally_authorized(workflow) do
        Crawling::Public.delete_for_lifecycle!(
          organization_id: workflow.organization_id,
          project_id: workflow.project_id,
          property_id: workflow.property_id,
          deletion_workflow_id: workflow.id
        )
      end
      DeletionStageResult.complete
    end

    def delete_objects(workflow, cursor)
      prefix = object_prefix(workflow)
      result = @object_store.delete_prefix(prefix: prefix, cursor: cursor)
      return DeletionStageResult.new(completed: false, cursor: result.cursor) unless result.completed?
      raise ObjectStoreUnavailable, "object deletion reconciliation found retained objects" if
        @object_store.objects_remaining?(prefix: prefix)

      DeletionStageResult.complete
    end

    def delete_aggregate(workflow)
      transactionally_authorized(workflow) do
        Verification::Public.delete_for_lifecycle!(
          organization_id: workflow.organization_id,
          project_id: workflow.project_id,
          property_id: workflow.property_id,
          deletion_workflow_id: workflow.id
        )
        Onboarding::Public.delete_for_lifecycle!(
          organization_id: workflow.organization_id,
          project_id: workflow.project_id,
          deletion_workflow_id: workflow.id
        ) if workflow.target_type == "Project"
        Properties::Public.delete_for_lifecycle!(
          organization_id: workflow.organization_id,
          project_id: workflow.project_id,
          property_id: workflow.property_id,
          deletion_workflow_id: workflow.id
        )
        Projects::Public.delete_for_lifecycle!(
          organization_id: workflow.organization_id,
          project_id: workflow.project_id,
          deletion_workflow_id: workflow.id
        ) if workflow.target_type == "Project"
      end
      DeletionStageResult.complete
    end

    def transactionally_authorized(workflow, &block)
      ActiveRecord::Base.transaction do
        DeletionContext.activate(workflow.id, &block)
      end
    end

    def object_prefix(workflow)
      base = "organizations/#{workflow.organization_id}/projects/#{workflow.project_id}"
      workflow.property_id ? "#{base}/properties/#{workflow.property_id}/" : "#{base}/"
    end
  end
end
