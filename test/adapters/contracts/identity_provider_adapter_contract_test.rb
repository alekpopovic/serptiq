# frozen_string_literal: true

require "test_helper"

class IdentityProviderAdapterContractTest < ActiveSupport::TestCase
  PROVIDERS = {
    "google" => TestSupport::GoogleProviderAdapterFake,
    "github" => TestSupport::GithubProviderAdapterFake
  }.freeze
  FAILURE_SCENARIOS = %i[access_denied malformed_response timeout rate_limited credentials_revoked].freeze

  test "Google and GitHub fakes satisfy the shared authorization and success contract" do
    PROVIDERS.each do |provider, adapter_class|
      configuration = configuration_for(provider)
      adapter = adapter_class.new(configuration: configuration)
      authorization = adapter.authorization_request(
        state: sensitive_state,
        nonce: provider == "google" ? sensitive_nonce : nil,
        code_challenge: code_challenge
      )

      assert_instance_of Identity::AuthorizationRequest, authorization
      assert_equal provider, authorization.provider
      assert_equal configuration.authorization_endpoint.host, authorization.uri.host
      query = Rack::Utils.parse_nested_query(authorization.uri.query)
      assert_equal sensitive_state, query.fetch("state")
      assert_equal "S256", query.fetch("code_challenge_method")
      assert_equal code_challenge, query.fetch("code_challenge")
      if provider == "google"
        assert_equal sensitive_nonce, query.fetch("nonce")
      else
        assert_nil query["nonce"]
      end

      assert_no_difference -> { Identity::User.count }, -> { Identity::ProviderIdentity.count } do
        exchange = adapter.exchange_callback(callback_input_for(configuration))
        assert_instance_of Identity::CallbackExchange, exchange
        assert_instance_of Identity::NormalizedIdentity, exchange.identity
        assert_equal provider, exchange.provider
        assert_equal "#{provider}-stable-subject", exchange.identity.subject
        assert exchange.identity.email_verified?
        if provider == "google"
          assert_instance_of Identity::OidcClaims, exchange.oidc_claims
          assert_equal sensitive_nonce, exchange.oidc_claims.nonce
        else
          assert_nil exchange.oidc_claims
        end
      end
    end
  end

  test "both fakes categorize every shared callback failure without leaking callback secrets" do
    PROVIDERS.each do |provider, adapter_class|
      FAILURE_SCENARIOS.each do |scenario|
        configuration = configuration_for(provider)
        adapter = adapter_class.new(configuration: configuration, scenario: scenario)
        input = callback_input_for(configuration)

        error = assert_raises(Identity::ProviderError) { adapter.exchange_callback(input) }

        assert_equal scenario.to_s, error.category
        assert_equal "callback_exchange", error.operation
        assert_equal scenario == :rate_limited, error.retry_after.present?
        assert_sensitive_values_absent(error.message, error.inspect, error.full_message, adapter.calls.inspect)
      end
    end
  end

  test "OIDC nonce remains provider-specific instead of being fabricated for GitHub" do
    google = TestSupport::GoogleProviderAdapterFake.new(configuration: configuration_for("google"))
    github = TestSupport::GithubProviderAdapterFake.new(configuration: configuration_for("github"))

    assert_raises(ArgumentError) do
      google.authorization_request(state: sensitive_state, code_challenge: code_challenge, nonce: nil)
    end
    assert_raises(ArgumentError) do
      github.authorization_request(state: sensitive_state, code_challenge: code_challenge, nonce: sensitive_nonce)
    end
  end

  test "contract value objects redact secrets and reject inconsistent protocol results" do
    configuration = configuration_for("google")
    input = callback_input_for(configuration)
    request = TestSupport::GoogleProviderAdapterFake.new(configuration: configuration).authorization_request(
      state: sensitive_state,
      nonce: sensitive_nonce,
      code_challenge: code_challenge
    )
    identity = Identity::NormalizedIdentity.new(
      provider: "github",
      subject: "github-subject",
      email: "private-user@example.test",
      email_verified: true
    )

    assert_sensitive_values_absent(input.inspect, request.inspect, identity.inspect)
    assert_raises(ArgumentError) { Identity::CallbackExchange.new(identity: identity, oidc_claims: oidc_claims) }
    assert_raises(ArgumentError) do
      google_identity = Identity::NormalizedIdentity.new(
        provider: "google", subject: "google-subject", email: nil, email_verified: false
      )
      Identity::CallbackExchange.new(identity: google_identity)
    end
  end

  private

  def configuration_for(provider)
    definition = Identity::ProviderConfiguration::DEFINITIONS.fetch(provider)
    Identity::ProviderConfiguration.new(
      provider: provider,
      client_id: "#{provider}-client-id",
      credential_available: true,
      issuer: definition.issuer,
      discovery_endpoint: definition.discovery_endpoint,
      authorization_endpoint: definition.authorization_endpoint,
      token_endpoint: definition.token_endpoint,
      jwks_endpoint: definition.jwks_endpoint,
      user_endpoint: definition.user_endpoint,
      emails_endpoint: definition.emails_endpoint,
      application_origin: "https://searchops.example",
      redirect_uri: "https://searchops.example#{definition.callback_path}"
    )
  end

  def callback_input_for(configuration)
    Identity::CallbackInput.new(
      code: sensitive_code,
      redirect_uri: configuration.redirect_uri,
      pkce_verifier: sensitive_verifier,
      nonce: configuration.oidc? ? sensitive_nonce : nil
    )
  end

  def oidc_claims
    Identity::OidcClaims.new(
      issuer: "https://accounts.google.com",
      subject: "google-subject",
      audiences: [ "google-client-id" ],
      authorized_party: "google-client-id",
      issued_at: Time.utc(2026, 9, 4, 3),
      expires_at: Time.utc(2026, 9, 4, 4),
      nonce: sensitive_nonce,
      key_id: "key-id",
      algorithm: "RS256"
    )
  end

  def assert_sensitive_values_absent(*outputs)
    combined = outputs.join(" ")
    [ sensitive_state, sensitive_nonce, sensitive_code, sensitive_verifier, "private-user@example.test" ].each do |secret|
      refute_includes combined, secret
    end
  end

  def sensitive_state
    "state-sensitive-value-that-must-not-leak"
  end

  def sensitive_nonce
    "nonce-sensitive-value-that-must-not-leak"
  end

  def sensitive_code
    "authorization-code-that-must-not-leak"
  end

  def sensitive_verifier
    "v" * 48
  end

  def code_challenge
    "c" * 43
  end
end
