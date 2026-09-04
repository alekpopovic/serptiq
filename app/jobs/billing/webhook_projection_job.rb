# frozen_string_literal: true

module Billing
  class WebhookProjectionJob < ApplicationJob
    class_attribute :processor_builder, default: -> { BillingWebhookProjectionFactory.build }

    runs_on :billing
    system_authorization :billing_webhook_projection,
      reason: "projects a verified durable provider event outside webhook ingress"

    def perform(webhook_event_id:)
      Public.process_webhook_event(
        processor: self.class.processor_builder.call,
        webhook_event_id: webhook_event_id
      )
    end
  end
end
