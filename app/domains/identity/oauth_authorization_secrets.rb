# frozen_string_literal: true

require "base64"
require "digest"
require "securerandom"

module Identity
  class OauthAuthorizationSecrets
    STATE_PATTERN = /\A[A-Za-z0-9_-]{43}\z/
    NONCE_PATTERN = STATE_PATTERN

    attr_reader :state, :nonce, :pkce_verifier, :pkce_challenge

    def self.generate(random_bytes: ->(length) { SecureRandom.random_bytes(length) })
      new(
        state: encode(random_bytes.call(32)),
        nonce: encode(random_bytes.call(32)),
        pkce_verifier: encode(random_bytes.call(64))
      )
    end

    def self.encode(value)
      Base64.urlsafe_encode64(value, padding: false)
    end
    private_class_method :encode

    def initialize(state:, nonce:, pkce_verifier:)
      @state = state.to_s.dup.freeze
      @nonce = nonce.to_s.dup.freeze
      @pkce_verifier = pkce_verifier.to_s.dup.freeze
      @pkce_challenge = Base64.urlsafe_encode64(
        Digest::SHA256.digest(@pkce_verifier),
        padding: false
      ).freeze
      validate!
      freeze
    end

    def inspect
      "#<#{self.class.name} state=[FILTERED] nonce=[FILTERED] " \
        "pkce_verifier=[FILTERED] pkce_challenge=[FILTERED]>"
    end

    private

    def validate!
      raise ArgumentError, "OAuth state is invalid" unless STATE_PATTERN.match?(state)
      raise ArgumentError, "OIDC nonce is invalid" unless NONCE_PATTERN.match?(nonce)
      unless OauthTransaction::PKCE_VERIFIER_PATTERN.match?(pkce_verifier)
        raise ArgumentError, "PKCE verifier is invalid"
      end
      raise ArgumentError, "PKCE challenge is invalid" unless STATE_PATTERN.match?(pkce_challenge)
    end
  end
end
