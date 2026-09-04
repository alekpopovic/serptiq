# frozen_string_literal: true

require "uri"

module Identity
  class ProviderConfiguration
    Definition = Data.define(
      :issuer,
      :discovery_endpoint,
      :authorization_endpoint,
      :token_endpoint,
      :jwks_endpoint,
      :user_endpoint,
      :emails_endpoint,
      :callback_path
    )

    DEFINITIONS = {
      "google" => Definition.new(
        "https://accounts.google.com",
        "https://accounts.google.com/.well-known/openid-configuration",
        "https://accounts.google.com/o/oauth2/v2/auth",
        "https://oauth2.googleapis.com/token",
        "https://www.googleapis.com/oauth2/v3/certs",
        "https://openidconnect.googleapis.com/v1/userinfo",
        nil,
        "/auth/google/callback"
      ),
      "github" => Definition.new(
        nil,
        nil,
        "https://github.com/login/oauth/authorize",
        "https://github.com/login/oauth/access_token",
        nil,
        "https://api.github.com/user",
        "https://api.github.com/user/emails",
        "/auth/github/callback"
      )
    }.freeze

    attr_reader :provider, :client_id, :issuer, :discovery_endpoint, :authorization_endpoint, :token_endpoint,
      :jwks_endpoint, :user_endpoint, :emails_endpoint, :redirect_uri

    def self.from_settings(provider:, settings: Rails.application.config.x.searchops)
      provider = provider.to_s
      definition = DEFINITIONS.fetch(provider) do
        raise ProviderError.new(
          category: "configuration",
          operation: "provider_lookup",
          reason_code: "provider_unknown"
        )
      end
      unless settings.fetch("oauth_#{provider}_enabled".to_sym)
        raise ProviderError.new(
          category: "configuration",
          operation: "provider_lookup",
          reason_code: "provider_unconfigured"
        )
      end

      origin = settings.fetch(:application_origin)
      new(
        provider: provider,
        client_id: settings.fetch("oauth_#{provider}_client_id".to_sym),
        credential_available: settings.secret("oauth_#{provider}_client_secret".to_sym).present?,
        issuer: definition.issuer,
        discovery_endpoint: definition.discovery_endpoint,
        authorization_endpoint: definition.authorization_endpoint,
        token_endpoint: definition.token_endpoint,
        jwks_endpoint: definition.jwks_endpoint,
        user_endpoint: definition.user_endpoint,
        emails_endpoint: definition.emails_endpoint,
        redirect_uri: URI.join("#{origin}/", definition.callback_path.delete_prefix("/")).to_s,
        application_origin: origin
      )
    end

    def initialize(provider:, client_id:, credential_available:, issuer:, discovery_endpoint:, authorization_endpoint:, token_endpoint:,
      jwks_endpoint:, user_endpoint:, emails_endpoint:, redirect_uri:, application_origin:)
      @provider = provider.to_s.dup.freeze
      @client_id = client_id.to_s.dup.freeze
      @credential_available = credential_available == true
      @issuer = parse_optional_uri(issuer)
      @discovery_endpoint = parse_optional_uri(discovery_endpoint)
      @authorization_endpoint = parse_uri(authorization_endpoint)
      @token_endpoint = parse_uri(token_endpoint)
      @jwks_endpoint = parse_optional_uri(jwks_endpoint)
      @user_endpoint = parse_uri(user_endpoint)
      @emails_endpoint = parse_optional_uri(emails_endpoint)
      @redirect_uri = parse_uri(redirect_uri)
      @application_origin = parse_uri(application_origin)
      validate!
      freeze_uris
      freeze
    end

    def endpoint_uris
      [ discovery_endpoint, authorization_endpoint, token_endpoint, jwks_endpoint, user_endpoint, emails_endpoint ].compact.freeze
    end

    def oidc?
      provider == "google"
    end

    def inspect
      "#<#{self.class.name} provider=#{provider.inspect} client_id=#{client_id.inspect} " \
        "redirect_uri=#{redirect_uri.inspect}>"
    end

    private

    def validate!
      definition = DEFINITIONS.fetch(provider) { raise_configuration("provider_unknown") }
      raise_configuration("provider_client_id_missing") if client_id.blank?
      raise_configuration("provider_credentials_missing") unless @credential_available
      validate_exact_uri!(:issuer, issuer, definition.issuer)
      validate_exact_uri!(:discovery_endpoint, discovery_endpoint, definition.discovery_endpoint)
      validate_exact_uri!(:authorization_endpoint, authorization_endpoint, definition.authorization_endpoint)
      validate_exact_uri!(:token_endpoint, token_endpoint, definition.token_endpoint)
      validate_exact_uri!(:jwks_endpoint, jwks_endpoint, definition.jwks_endpoint)
      validate_exact_uri!(:user_endpoint, user_endpoint, definition.user_endpoint)
      validate_exact_uri!(:emails_endpoint, emails_endpoint, definition.emails_endpoint)
      validate_application_origin!

      expected_redirect = URI.join(
        "#{@application_origin}/",
        definition.callback_path.delete_prefix("/")
      )
      raise_configuration("provider_redirect_uri_mismatch") unless redirect_uri == expected_redirect
      validate_application_uri!(redirect_uri)
    end

    def validate_exact_uri!(name, actual, expected)
      expected_uri = parse_optional_uri(expected)
      raise_configuration("provider_#{name}_mismatch") unless actual == expected_uri
      validate_https_uri!(actual) if actual
    end

    def validate_https_uri!(uri)
      valid = uri.scheme == "https" && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
      raise_configuration("provider_endpoint_unsafe") unless valid
    end

    def validate_application_uri!(uri)
      valid_scheme = uri.scheme == "https" || (uri.scheme == "http" && loopback_host?(uri.host))
      valid = valid_scheme && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
      raise_configuration("provider_redirect_uri_unsafe") unless valid
    end

    def validate_application_origin!
      validate_application_uri!(@application_origin)
      raise_configuration("provider_redirect_uri_unsafe") unless [ "", "/" ].include?(@application_origin.path)
    end

    def loopback_host?(host)
      [ "localhost", "127.0.0.1", "::1" ].include?(host.to_s.downcase)
    end

    def parse_uri(value)
      URI.parse(value.to_s)
    rescue URI::InvalidURIError
      raise_configuration("provider_endpoint_invalid")
    end

    def parse_optional_uri(value)
      value.nil? ? nil : parse_uri(value)
    end

    def raise_configuration(reason_code)
      raise ProviderError.new(
        category: "configuration",
        operation: "provider_configuration",
        reason_code: reason_code
      ), cause: nil
    end

    def freeze_uris
      [ issuer, *endpoint_uris, redirect_uri, @application_origin ].compact.each(&:freeze)
    end
  end
end
