# frozen_string_literal: true

module Billing
  module LemonSqueezy
    class Instrumentation
      EVENT_NAME = "billing.provider_request"

      def initialize(emitter: nil)
        @emitter = emitter
      end

      def emit(outcome:, operation:, duration_ms:, retry_count:, http_status: nil, error_category: nil)
        attributes = {
          severity: outcome == "failed" ? :warn : :info,
          outcome: outcome,
          provider: "lemon_squeezy",
          operation: operation,
          duration_ms: duration_ms,
          retry_count: retry_count,
          http_status: http_status,
          error_category: error_category
        }
        if @emitter
          @emitter.emit(EVENT_NAME, **attributes)
        else
          Shared::Public.emit_structured_event(EVENT_NAME, **attributes)
        end
      rescue StandardError => error
        Shared::Public.report_observability_failure(error, event_name: EVENT_NAME)
        nil
      end
    end
  end
end
