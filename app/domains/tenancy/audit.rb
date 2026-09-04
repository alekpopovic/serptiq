# frozen_string_literal: true

module Tenancy
  module Audit
    module_function

    def emit(event_name, outcome:, operation:, reason_code: nil, actor_membership_id: nil,
      subject_membership_id: nil)
      Shared::Public.with_audit_principals(
        actor_id: actor_membership_id,
        subject_id: subject_membership_id
      ) do
        Shared::Public.emit_structured_event(
          event_name,
          outcome: outcome,
          operation: operation,
          reason_code: reason_code
        )
      end
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: event_name)
      nil
    end
  end
end
