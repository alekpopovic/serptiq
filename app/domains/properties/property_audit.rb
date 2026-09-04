# frozen_string_literal: true

module Properties
  module PropertyAudit
    module_function

    def record!(action:, actor_membership_id:, property:, operation:, metadata: {})
      Auditing::Public.record!(
        organization_id: property.organization_id,
        actor_membership_id: actor_membership_id,
        action: action,
        target_type: "Property",
        target_id: property.id,
        result: "succeeded",
        metadata: metadata.merge(operation: operation, event_kind: property.kind)
      )
      emit(action, actor_membership_id, property.organization_id, operation)
    end

    def emit(action, actor_id, organization_id, operation)
      Shared::Public.with_tenant_audit(
        organization_id: organization_id, actor_id: actor_id, subject_id: nil
      ) do
        Shared::Public.emit_structured_event(action, outcome: "succeeded", operation: operation)
      end
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: action)
    end
    private_class_method :emit
  end
end
