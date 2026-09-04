# frozen_string_literal: true

require "base64"
require "digest"
require "openssl"

module Verification
  module ChallengeToken
    PREFIX = "searchops-verification="
    KEY_PURPOSE = "verification/domain-challenge/v1"

    module_function

    def value_for(challenge)
      material = [
        challenge.id, challenge.organization_id, challenge.environment_id,
        challenge.method, challenge.bound_origin
      ].join(":")
      encoded = Base64.urlsafe_encode64(OpenSSL::HMAC.digest("SHA256", key, material), padding: false)
      "#{PREFIX}#{encoded}".freeze
    end

    def digest(value)
      Digest::SHA256.hexdigest(value.to_s)
    end

    def valid_for?(challenge, value)
      ActiveSupport::SecurityUtils.secure_compare(
        challenge.challenge_digest,
        digest(value)
      )
    end

    def key
      Rails.application.key_generator.generate_key(KEY_PURPOSE, 32)
    end
    private_class_method :key
  end
end
