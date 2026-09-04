# frozen_string_literal: true

module Billing
  class WebhookIngressInstrumentation
    def emit(outcome:, reason_code:, http_status:)
      Shared::Public.emit_structured_event(
        "billing.webhook_ingress",
        severity: outcome == "succeeded" ? :info : :warn,
        outcome: outcome,
        operation: "receive_webhook",
        provider: "lemon_squeezy",
        reason_code: reason_code,
        http_status: http_status
      )
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "billing.webhook_ingress")
      nil
    end
  end
end
