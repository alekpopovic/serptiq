# frozen_string_literal: true

module Billing
  class WebhookPayloadCorrupt < Shared::Public::ConflictError
    def initialize(reason_code: "billing_webhook_payload_corrupt")
      super
    end
  end
end
