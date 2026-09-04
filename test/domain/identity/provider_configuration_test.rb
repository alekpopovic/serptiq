# frozen_string_literal: true

require "test_helper"

class IdentityProviderConfigurationTest < ActiveSupport::TestCase
  class Settings
    def initialize(public_values:, secrets: {})
      @public_values = public_values
      @secrets = secrets
    end

    def fetch(key)
      @public_values.fetch(key)
    end

    def secret(key)
      @secrets[key]
    end
  end

  test "uses the exact allowlisted Google OIDC and GitHub OAuth endpoints" do
    google = configuration_for("google")
    github = configuration_for("github")

    assert google.oidc?
    assert_equal URI("https://accounts.google.com"), google.issuer
    assert_equal URI("https://accounts.google.com/.well-known/openid-configuration"), google.discovery_endpoint
    assert_equal URI("https://accounts.google.com/o/oauth2/v2/auth"), google.authorization_endpoint
    assert_equal URI("https://oauth2.googleapis.com/token"), google.token_endpoint
    assert_equal URI("https://www.googleapis.com/oauth2/v3/certs"), google.jwks_endpoint
    assert_equal URI("https://openidconnect.googleapis.com/v1/userinfo"), google.user_endpoint
    assert_nil google.emails_endpoint
    assert_equal URI("https://searchops.example/auth/google/callback"), google.redirect_uri

    refute github.oidc?
    assert_nil github.issuer
    assert_nil github.discovery_endpoint
    assert_nil github.jwks_endpoint
    assert_equal URI("https://github.com/login/oauth/authorize"), github.authorization_endpoint
    assert_equal URI("https://github.com/login/oauth/access_token"), github.token_endpoint
    assert_equal URI("https://api.github.com/user"), github.user_endpoint
    assert_equal URI("https://api.github.com/user/emails"), github.emails_endpoint
    assert_equal URI("https://searchops.example/auth/github/callback"), github.redirect_uri
  end

  test "rejects unknown disabled incomplete unsafe and mismatched provider configuration" do
    unknown = assert_raises(Identity::ProviderError) do
      Identity::ProviderConfiguration.from_settings(provider: "unknown", settings: settings)
    end
    assert_equal "provider_unknown", unknown.reason_code

    disabled = assert_raises(Identity::ProviderError) do
      Identity::ProviderConfiguration.from_settings(provider: "github", settings: settings(github_enabled: false))
    end
    assert_equal "provider_unconfigured", disabled.reason_code

    missing_secret = assert_raises(Identity::ProviderError) do
      Identity::ProviderConfiguration.from_settings(provider: "google", settings: settings(google_secret: nil))
    end
    assert_equal "provider_credentials_missing", missing_secret.reason_code

    unsafe_origin = assert_raises(Identity::ProviderError) do
      build_configuration("google", application_origin: "http://provider-attacker.example",
        redirect_uri: "http://provider-attacker.example/auth/google/callback")
    end
    assert_equal "provider_redirect_uri_unsafe", unsafe_origin.reason_code

    origin_with_path = assert_raises(Identity::ProviderError) do
      build_configuration("google", application_origin: "https://searchops.example/unexpected-path")
    end
    assert_equal "provider_redirect_uri_unsafe", origin_with_path.reason_code

    endpoint_substitution = assert_raises(Identity::ProviderError) do
      build_configuration("github", token_endpoint: "https://provider-attacker.example/token")
    end
    assert_equal "provider_token_endpoint_mismatch", endpoint_substitution.reason_code

    redirect_substitution = assert_raises(Identity::ProviderError) do
      build_configuration("github", redirect_uri: "https://searchops.example/auth/google/callback")
    end
    assert_equal "provider_redirect_uri_mismatch", redirect_substitution.reason_code
  end

  test "registry exposes only configured allowlisted adapters" do
    adapter_classes = {
      "google" => TestSupport::GoogleProviderAdapterFake,
      "github" => TestSupport::GithubProviderAdapterFake
    }
    registry = Identity::ProviderRegistry.from_settings(settings: settings) do |configuration|
      adapter_classes.fetch(configuration.provider).new(configuration: configuration)
    end

    assert_equal %w[github google], registry.configured_providers
    assert_instance_of TestSupport::GoogleProviderAdapterFake, registry.fetch(:google)
    assert_instance_of TestSupport::GithubProviderAdapterFake, registry.fetch("github")

    unknown = assert_raises(Identity::ProviderError) { registry.fetch("gitlab") }
    assert_equal "provider_unknown", unknown.reason_code

    empty_registry = Identity::ProviderRegistry.new(configurations: [], adapters: {})
    unconfigured = assert_raises(Identity::ProviderError) { empty_registry.fetch("google") }
    assert_equal "provider_unconfigured", unconfigured.reason_code
  end

  test "registry rejects adapters bound to a different configuration instance" do
    registered_configuration = configuration_for("google")
    other_configuration = configuration_for("google")
    adapter = TestSupport::GoogleProviderAdapterFake.new(configuration: other_configuration)

    assert_raises(ArgumentError) do
      Identity::ProviderRegistry.new(
        configurations: [ registered_configuration ],
        adapters: { "google" => adapter }
      )
    end
  end

  private

  def settings(github_enabled: true, google_secret: "synthetic-google-secret")
    Settings.new(
      public_values: {
        application_origin: "https://searchops.example",
        oauth_google_enabled: true,
        oauth_google_client_id: "google-client-id",
        oauth_github_enabled: github_enabled,
        oauth_github_client_id: "github-client-id"
      },
      secrets: {
        oauth_google_client_secret: google_secret,
        oauth_github_client_secret: "synthetic-github-secret"
      }
    )
  end

  def configuration_for(provider)
    Identity::ProviderConfiguration.from_settings(provider: provider, settings: settings)
  end

  def build_configuration(provider, **overrides)
    definition = Identity::ProviderConfiguration::DEFINITIONS.fetch(provider)
    attributes = {
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
    }
    Identity::ProviderConfiguration.new(**attributes.merge(overrides))
  end
end
