# frozen_string_literal: true

require "openssl"
require "securerandom"

module Identity
  module TokenDigest
    TOKEN_PREFIX = "so_s1_"
    TOKEN_PATTERN = /\Aso_s1_[A-Za-z0-9_-]{43}\z/
    KEY_PURPOSE = "identity/session-token-digest/v1"

    module_function

    def generate
      "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(32, false)}"
    end

    def call(raw_token)
      token = raw_token.to_s
      raise InvalidSession unless TOKEN_PATTERN.match?(token)

      OpenSSL::HMAC.hexdigest("SHA256", key, token)
    end

    def key
      Rails.application.key_generator.generate_key(KEY_PURPOSE, 32)
    end
    private_class_method :key
  end
end
