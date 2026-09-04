# frozen_string_literal: true

require "test_helper"

class GoogleIdTokenValidatorTest < ActiveSupport::TestCase
  setup do
    @now = Time.current.change(usec: 0)
    @secrets = deterministic_oauth_secrets
    @input = callback_input
    @validator = build_validator
  end

  test "verifies signature and every required Google OIDC claim" do
    claims, payload = @validator.call(
      token: google_id_token(claims: google_id_token_claims(now: @now, nonce: @secrets.nonce)),
      callback_input: @input
    )

    assert_equal "https://accounts.google.com", claims.issuer
    assert_equal "synthetic-google-subject", claims.subject
    assert_equal [ "synthetic-google-client-id" ], claims.audiences
    assert_equal "synthetic-google-client-id", claims.authorized_party
    assert_equal @now, claims.issued_at
    assert_equal @now + 1.hour, claims.expires_at
    assert_equal @secrets.nonce, claims.nonce
    assert_equal "RS256", claims.algorithm
    assert_equal "google-user@example.test", payload.fetch("email")
    refute_includes claims.inspect, @secrets.nonce
  end

  test "rejects algorithm key ID embedded-key and signature confusion" do
    cases = {
      "wrong algorithm" => google_id_token(
        claims: google_id_token_claims(now: @now, nonce: @secrets.nonce), header: { "alg" => "HS256" }
      ),
      "unknown key" => google_id_token(
        claims: google_id_token_claims(now: @now, nonce: @secrets.nonce), header: { "kid" => "unknown-key" }
      ),
      "embedded key" => google_id_token(
        claims: google_id_token_claims(now: @now, nonce: @secrets.nonce), header: { "jwk" => google_jwk }
      ),
      "bad signature" => google_id_token(
        claims: google_id_token_claims(now: @now, nonce: @secrets.nonce), key: OpenSSL::PKey::RSA.generate(2048)
      )
    }

    cases.each do |_name, token|
      error = assert_raises(Identity::ProviderError) { @validator.call(token: token, callback_input: @input) }
      assert_equal "malformed_response", error.category
    end
  end

  test "rejects issuer audience and authorized-party confusion" do
    invalid_claims = [
      { "iss" => "accounts.google.com" },
      { "aud" => "other-client" },
      { "aud" => [ "synthetic-google-client-id", "mobile-client" ], "azp" => nil },
      { "aud" => [ "synthetic-google-client-id", "mobile-client" ], "azp" => "mobile-client" }
    ]

    invalid_claims.each do |overrides|
      assert_invalid_claims(overrides)
    end
  end

  test "rejects expired future and stale issued-at timestamps" do
    invalid_claims = [
      { "exp" => (@now - 61.seconds).to_i },
      { "nbf" => (@now + 61.seconds).to_i },
      { "iat" => (@now + 61.seconds).to_i },
      { "iat" => (@now - 3.minutes).to_i },
      { "exp" => (@now + 3.hours).to_i }
    ]

    invalid_claims.each do |overrides|
      assert_invalid_claims(overrides)
    end
  end

  test "rejects nonce mismatch malformed payloads and noncanonical compact tokens" do
    assert_invalid_claims("nonce" => "different-#{'n' * 32}")
    assert_raises(Identity::ProviderError) { @validator.call(token: "not.a.jwt.extra", callback_input: @input) }

    token = google_id_token(claims: google_id_token_claims(now: @now, nonce: @secrets.nonce))
    assert_raises(Identity::ProviderError) { @validator.call(token: "#{token}.extra", callback_input: @input) }
    header, payload, signature = token.split(".")
    noncanonical = [ "#{header}=", payload, signature ].join(".")
    assert_raises(Identity::ProviderError) { @validator.call(token: noncanonical, callback_input: @input) }
  end

  private

  def build_validator
    cache = Identity::GoogleJwksCache.new(
      fetcher: -> { { "keys" => [ google_jwk ] } }, ttl: 5.minutes, max_keys: 4, clock: -> { @now }
    )
    Identity::GoogleIdTokenValidator.new(
      configuration: build_google_configuration,
      jwks_cache: cache,
      clock_skew: 60,
      max_token_lifetime: 2.hours,
      clock: -> { @now }
    )
  end

  def callback_input
    Identity::CallbackInput.new(
      code: "synthetic-authorization-code",
      redirect_uri: build_google_configuration.redirect_uri,
      pkce_verifier: @secrets.pkce_verifier,
      nonce_digest: Identity::SecretDigest.call(@secrets.nonce, purpose: "oauth-nonce"),
      issued_after: @now - 1.minute
    )
  end

  def assert_invalid_claims(overrides)
    claims = google_id_token_claims(now: @now, nonce: @secrets.nonce, **overrides)
    error = assert_raises(Identity::ProviderError) do
      @validator.call(token: google_id_token(claims: claims), callback_input: @input)
    end
    assert_equal "malformed_response", error.category
  end
end
