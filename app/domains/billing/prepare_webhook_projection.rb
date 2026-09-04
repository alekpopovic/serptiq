# frozen_string_literal: true

module Billing
  class PrepareWebhookProjection
    def call(webhook_event_id:)
      event = WebhookEvent.find(webhook_event_id)
      event.payload
      Shared::Public.emit_structured_event(
        "billing.webhook_projection_ready",
        outcome: "succeeded",
        operation: "prepare_projection",
        provider: event.provider,
        reason_code: event.state
      )
      event.summary
    end
  end
end
