# frozen_string_literal: true

require "active_support/message_encryptor"
require "json"

module Identity
  module ProtectedValue
    PURPOSE_PATTERN = /\A[a-z][a-z0-9_-]{0,63}\z/

    module_function

    def encrypt(value, purpose:)
      validate_purpose!(purpose)
      encryptor(purpose).encrypt_and_sign(value.to_s, purpose: purpose)
    end

    def decrypt(ciphertext, purpose:)
      validate_purpose!(purpose)
      encryptor(purpose).decrypt_and_verify(ciphertext, purpose: purpose)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
      raise CorruptOauthTransaction
    end

    def encryptor(purpose)
      key = Rails.application.key_generator.generate_key("identity/#{purpose}/encryption/v1", 32)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
    end
    private_class_method :encryptor

    def validate_purpose!(purpose)
      raise ArgumentError, "invalid encryption purpose" unless PURPOSE_PATTERN.match?(purpose.to_s)
    end
    private_class_method :validate_purpose!
  end
end
