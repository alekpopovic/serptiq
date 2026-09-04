# frozen_string_literal: true

module Billing
  class WebhookProjectionJob < ApplicationJob
    runs_on :billing
    system_authorization :billing_webhook_projection,
      reason: "projects a verified durable provider event outside webhook ingress"

    def perform(webhook_event_id:)
      Public.prepare_webhook_projection(webhook_event_id: webhook_event_id)
    end
  end
end
