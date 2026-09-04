# frozen_string_literal: true

module Billing
  class BoundedWebhookBody
    MAX_BYTES = VerifiedWebhook::MAX_BODY_BYTES

    def call(io:, content_length: nil)
      declared = Integer(content_length.to_s, 10) if content_length.present?
      raise WebhookBodyTooLarge if declared && declared > MAX_BYTES

      body = io.read(MAX_BYTES + 1).to_s
      raise WebhookBodyTooLarge if body.bytesize > MAX_BYTES

      body.b
    rescue ArgumentError, TypeError
      raise WebhookBodyTooLarge
    end
  end
end
