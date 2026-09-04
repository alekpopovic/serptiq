# frozen_string_literal: true

module Authorization
  class DecisionInstrumentation
    HIGH_RISKS = %w[high critical].freeze

    def emit(decision, permission: nil)
      event_name = if decision.deny? && permission && HIGH_RISKS.include?(permission.risk_level)
        "authorization.denied_high_risk"
      else
        "authorization.decision_evaluated"
      end
      operation = permission ? permission.key : "unknown_permission"
      Shared::Public.with_authorization_decision(
        organization_id: decision.organization_id.presence,
        actor_id: @actor_id,
        scope_id: decision.scope_id.presence,
        scope_type: decision.scope_type
      ) do
        Shared::Public.emit_structured_event(
          event_name,
          outcome: decision.allow? ? "succeeded" : "denied",
          operation: operation,
          reason_code: decision.reason_code
        )
      end
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: event_name || "authorization.decision_evaluated")
      nil
    end

    def with_actor(actor_id)
      duplicate = dup
      duplicate.instance_variable_set(:@actor_id, actor_id)
      duplicate
    end
  end
end
