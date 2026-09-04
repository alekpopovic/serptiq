# frozen_string_literal: true

module Tenancy
  module Audit
    module_function

    def emit(event_name, outcome:, operation:, reason_code: nil)
      Shared::Public.emit_structured_event(
        event_name,
        outcome: outcome,
        operation: operation,
        reason_code: reason_code
      )
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: event_name)
      nil
    end
  end
end
