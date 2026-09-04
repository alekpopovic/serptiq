# frozen_string_literal: true

module Identity
  module Audit
    module_function

    def emit(event_name, outcome:, reason_code: nil)
      Shared::Public.emit_structured_event(
        event_name,
        outcome: outcome,
        reason_code: reason_code
      )
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: event_name)
      nil
    end
  end
end
