# frozen_string_literal: true

require "active_support/message_encryptor"
require "json"

module Billing
  class WebhookPayloadCipher
    PURPOSE = "billing-webhook-payload-v1"

    def encrypt(raw_body)
      encryptor.encrypt_and_sign(raw_body.to_s.b, purpose: PURPOSE)
    end

    def decrypt(ciphertext)
      encryptor.decrypt_and_verify(ciphertext.to_s, purpose: PURPOSE).to_s.b
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
      raise WebhookPayloadCorrupt, cause: nil
    end

    private

    def encryptor
      key = Rails.application.key_generator.generate_key("billing/webhook/payload/encryption/v1", 32)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
    end
  end
end
