# frozen_string_literal: true

module Authorization
  module Audit
    module_function

    def emit(event_name, organization_id:, actor_id:, principal_type:, principal_id:, role_id:,
      scope_type:, scope_id:, outcome:, operation:, reason_code: nil)
      Shared::Public.with_authorization_audit(
        organization_id: organization_id,
        actor_id: actor_id,
        principal_id: principal_id,
        role_id: role_id,
        scope_id: scope_id,
        principal_type: principal_type,
        scope_type: scope_type
      ) do
        Shared::Public.emit_structured_event(
          event_name, outcome: outcome, operation: operation, reason_code: reason_code
        )
      end
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: event_name)
      nil
    end
  end
end
