# frozen_string_literal: true

require "openssl"
require "securerandom"

module Tenancy
  module InvitationToken
    PREFIX = "so_i1_"
    PATTERN = /\Aso_i1_[A-Za-z0-9_-]{43}\z/
    PURPOSE = "tenancy/invitation-token-digest/v1"

    module_function

    def generate
      "#{PREFIX}#{SecureRandom.urlsafe_base64(32, false)}"
    end

    def digest(token)
      value = token.to_s
      raise ArgumentError, "invalid invitation token" unless PATTERN.match?(value)

      OpenSSL::HMAC.hexdigest("SHA256", key, value)
    end

    def valid?(token)
      PATTERN.match?(token.to_s)
    end

    def key
      Rails.application.key_generator.generate_key(PURPOSE, 32)
    end
    private_class_method :key
  end
end
