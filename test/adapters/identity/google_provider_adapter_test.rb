# frozen_string_literal: true

require "test_helper"

class GoogleProviderAdapterTest < ActiveSupport::TestCase
  class FakeHttpClient
    attr_reader :calls

    def initialize(response)
      @response = response
      @calls = []
    end

    def post_form_json(**request)
      calls << request.deep_dup
      @response.deep_dup
    end
  end

  setup do
    @now = Time.current.change(usec: 0)
    @secrets = deterministic_oauth_secrets
    @token = google_id_token(claims: google_id_token_claims(now: @now, nonce: @secrets.nonce))
  end

  test "exchanges the code with exact PKCE form fields and returns a normalized verified identity" do
    http = FakeHttpClient.new({ "id_token" => @token, "token_type" => "Bearer", "access_token" => "ignored-secret" })
    adapter = build_adapter(http)

    exchange = adapter.exchange_callback(callback_input)

    assert_equal "google", exchange.provider
    assert_equal "synthetic-google-subject", exchange.identity.subject
    assert_equal "google-user@example.test", exchange.identity.email
    assert exchange.identity.email_verified?
    assert_equal({
      code: "synthetic-authorization-code",
      client_id: "synthetic-google-client-id",
      client_secret: "synthetic-google-client-secret",
      redirect_uri: "https://searchops.test/auth/google/callback",
      grant_type: "authorization_code",
      code_verifier: @secrets.pkce_verifier
    }, http.calls.sole.fetch(:form))
    assert_equal URI("https://oauth2.googleapis.com/token"), http.calls.sole.fetch(:uri)
    assert_equal "token_exchange", http.calls.sole.fetch(:operation)
    refute_includes exchange.inspect, @token
    refute_includes adapter.inspect, "synthetic-google-client-secret"
    refute_includes adapter.inspect, @token
  end

  test "retains unverified email only as a non-authoritative observation" do
    claims = google_id_token_claims(
      now: @now, nonce: @secrets.nonce, "email" => "unverified@example.test", "email_verified" => false
    )
    exchange = build_adapter(FakeHttpClient.new({ "id_token" => google_id_token(claims: claims) }))
      .exchange_callback(callback_input)

    assert_equal "unverified@example.test", exchange.identity.email
    refute exchange.identity.email_verified?
  end

  test "rejects missing ID token invalid token type and false verified-email assertions" do
    responses = [
      {},
      { "id_token" => @token, "token_type" => "MAC" },
      { "id_token" => google_id_token(claims: google_id_token_claims(
        now: @now, nonce: @secrets.nonce, "email" => nil, "email_verified" => true
      )) }
    ]

    responses.each do |response|
      error = assert_raises(Identity::ProviderError) do
        build_adapter(FakeHttpClient.new(response)).exchange_callback(callback_input)
      end
      assert_equal "malformed_response", error.category
      refute_includes error.inspect, @token
    end
  end

  test "rejects a callback redirect substitution before code exchange" do
    http = FakeHttpClient.new({ "id_token" => @token })
    input = Identity::CallbackInput.new(
      code: "synthetic-authorization-code",
      redirect_uri: "https://searchops.test/other-callback",
      pkce_verifier: @secrets.pkce_verifier,
      nonce: @secrets.nonce,
      issued_after: @now - 1.minute
    )

    error = assert_raises(Identity::ProviderError) { build_adapter(http).exchange_callback(input) }

    assert_equal "google_redirect_uri_mismatch", error.reason_code
    assert_empty http.calls
  end

  private

  def build_adapter(http)
    cache = Identity::GoogleJwksCache.new(
      fetcher: -> { { "keys" => [ google_jwk ] } }, ttl: 5.minutes, max_keys: 4, clock: -> { @now }
    )
    validator = Identity::GoogleIdTokenValidator.new(
      configuration: build_google_configuration,
      jwks_cache: cache,
      clock_skew: 60,
      max_token_lifetime: 2.hours,
      clock: -> { @now }
    )
    Identity::GoogleProviderAdapter.new(
      configuration: build_google_configuration,
      client_secret: "synthetic-google-client-secret",
      http_client: http,
      id_token_validator: validator
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
end
