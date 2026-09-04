# frozen_string_literal: true

require "base64"
require "digest"

module TestSupport
  module GoogleOauthHelpers
    def build_google_configuration(origin: "https://searchops.test")
      definition = Identity::ProviderConfiguration::DEFINITIONS.fetch("google")
      Identity::ProviderConfiguration.new(
        provider: "google",
        client_id: "synthetic-google-client-id",
        credential_available: true,
        issuer: definition.issuer,
        discovery_endpoint: definition.discovery_endpoint,
        authorization_endpoint: definition.authorization_endpoint,
        token_endpoint: definition.token_endpoint,
        jwks_endpoint: definition.jwks_endpoint,
        user_endpoint: definition.user_endpoint,
        emails_endpoint: definition.emails_endpoint,
        application_origin: origin,
        redirect_uri: "#{origin}/auth/google/callback"
      )
    end

    def build_oauth_initiation_policy(**overrides)
      defaults = {
        transaction_ttl: 10.minutes,
        retention: 24.hours,
        rate_window: 5.minutes,
        max_per_ip: 20,
        max_per_session: 10,
        max_open_per_ip: 5,
        max_open_per_session: 2
      }
      Identity::OauthInitiationPolicy.new(**defaults.merge(overrides))
    end

    def build_google_authorization_starter(policy: build_oauth_initiation_policy, clock: -> { Time.current },
      secret_generator: -> { deterministic_oauth_secrets })
      configuration = build_google_configuration
      Identity::GoogleAuthorizationStarter.new(
        adapter: Identity::GoogleProviderAdapter.new(configuration: configuration),
        limiter: Identity::OauthInitiationLimiter.new(policy: policy),
        policy: policy,
        clock: clock,
        secret_generator: secret_generator
      )
    end

    def deterministic_oauth_secrets(sequence = 1)
      Identity::OauthAuthorizationSecrets.new(
        state: Base64.urlsafe_encode64(Digest::SHA256.digest("state-#{sequence}"), padding: false),
        nonce: Base64.urlsafe_encode64(Digest::SHA256.digest("nonce-#{sequence}"), padding: false),
        pkce_verifier: Base64.urlsafe_encode64(Digest::SHA512.digest("verifier-#{sequence}"), padding: false)
      )
    end
  end
end
