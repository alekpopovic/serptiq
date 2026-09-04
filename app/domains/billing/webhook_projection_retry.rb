# frozen_string_literal: true

module Billing
  class WebhookProjectionRetry < Shared::Public::TransientInfrastructureError
    def initialize
      super(reason_code: "billing_webhook_projection_retry")
    end
  end
end
