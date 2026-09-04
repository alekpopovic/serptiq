# frozen_string_literal: true

require "openssl"

module Shared
  module Observability
    class IdentifierHasher
      PURPOSE = "searchops-observability-organization-id"
      OUTPUT_LENGTH = 24

      def self.default
        secret = Rails.application.key_generator.generate_key(PURPOSE, 32)
        new(secret: secret)
      end

      def initialize(secret:)
        raise ArgumentError, "identifier hashing secret is required" if secret.nil? || secret.empty?

        @secret = secret
      end

      def call(identifier)
        value = identifier.to_s
        raise ArgumentError, "organization identifier is required" if value.empty?

        OpenSSL::HMAC.hexdigest("SHA256", @secret, value).first(OUTPUT_LENGTH).freeze
      end
    end
  end
end
