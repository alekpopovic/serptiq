# frozen_string_literal: true

module Authorization
  class AccessInstrumentation
    def emit(decision, request:)
      Shared::Public.with_authorization_decision(
        organization_id: request.organization_id.presence,
        actor_id: request.actor_membership_id,
        scope_id: request.scope_id.presence,
        scope_type: request.scope_type
      ) do
        Shared::Public.emit_structured_event(
          "access.decision_evaluated",
          outcome: decision.allow? ? "succeeded" : "denied",
          operation: request.permission_key,
          reason_code: decision.reason_code
        )
        emit_reservation(request) if decision.reserved?
      end
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "access.decision_evaluated")
      nil
    end

    private

    def emit_reservation(request)
      Shared::Public.emit_structured_event(
        "access.quota_reserved",
        outcome: "succeeded",
        operation: request.permission_key,
        reason_code: "quota_reserved"
      )
    end
  end
end
