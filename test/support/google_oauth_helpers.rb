# frozen_string_literal: true

require "base64"
require "digest"
require "json"
require "openssl"

module TestSupport
  module GoogleOauthHelpers
    TEST_GOOGLE_RSA_KEY = OpenSSL::PKey::RSA.generate(2048)
    TEST_GOOGLE_KEY_ID = "synthetic-google-key-1"

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

    def google_jwk(key: TEST_GOOGLE_RSA_KEY, key_id: TEST_GOOGLE_KEY_ID)
      {
        "kty" => "RSA",
        "alg" => "RS256",
        "use" => "sig",
        "kid" => key_id,
        "n" => Base64.urlsafe_encode64(key.n.to_s(2), padding: false),
        "e" => Base64.urlsafe_encode64(key.e.to_s(2), padding: false)
      }
    end

    def google_id_token(claims: google_id_token_claims, header: {}, key: TEST_GOOGLE_RSA_KEY)
      protected_header = { "alg" => "RS256", "kid" => TEST_GOOGLE_KEY_ID, "typ" => "JWT" }.merge(header)
      segments = [ protected_header, claims ].map do |value|
        Base64.urlsafe_encode64(JSON.generate(value), padding: false)
      end
      signature = key.sign(OpenSSL::Digest::SHA256.new, segments.join("."))
      [ *segments, Base64.urlsafe_encode64(signature, padding: false) ].join(".")
    end

    def google_id_token_claims(now: Time.current.change(usec: 0), nonce: deterministic_oauth_secrets.nonce, **overrides)
      {
        "iss" => "https://accounts.google.com",
        "sub" => "synthetic-google-subject",
        "aud" => "synthetic-google-client-id",
        "azp" => "synthetic-google-client-id",
        "iat" => now.to_i,
        "exp" => (now + 1.hour).to_i,
        "nonce" => nonce,
        "email" => "google-user@example.test",
        "email_verified" => true,
        "name" => "Synthetic Google User",
        "picture" => "https://images.example.test/avatar.png",
        "locale" => "en"
      }.merge(overrides)
    end
  end
end
