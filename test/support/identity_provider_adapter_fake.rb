# frozen_string_literal: true

require "uri"

module TestSupport
  class IdentityProviderAdapterFake < Identity::ProviderAdapter
    SCENARIOS = %i[success access_denied malformed_response timeout rate_limited credentials_revoked].freeze
    PKCE_CHALLENGE_PATTERN = /\A[A-Za-z0-9_-]{43,128}\z/

    attr_reader :calls, :scenario

    def initialize(configuration:, scenario: :success)
      super(configuration: configuration)
      @scenario = scenario.to_sym
      raise ArgumentError, "unsupported fake scenario" unless SCENARIOS.include?(@scenario)

      @calls = []
    end

    def authorization_request(state:, code_challenge:, nonce: nil)
      raise ArgumentError, "state is required" if state.blank?
      raise ArgumentError, "PKCE challenge is invalid" unless PKCE_CHALLENGE_PATTERN.match?(code_challenge.to_s)
      raise ArgumentError, "Google OIDC nonce is required" if configuration.oidc? && nonce.blank?
      raise ArgumentError, "GitHub OAuth does not accept an OIDC nonce" if !configuration.oidc? && nonce.present?

      query = {
        client_id: configuration.client_id,
        redirect_uri: configuration.redirect_uri.to_s,
        response_type: "code",
        scope: configuration.oidc? ? "openid email profile" : "read:user user:email",
        state: state,
        code_challenge: code_challenge,
        code_challenge_method: "S256"
      }
      query[:nonce] = nonce if configuration.oidc?
      uri = configuration.authorization_endpoint.dup
      uri.query = URI.encode_www_form(query)
      Identity::AuthorizationRequest.new(provider: provider, uri: uri)
    end

    def exchange_callback(input)
      raise ArgumentError, "callback input is required" unless input.is_a?(Identity::CallbackInput)
      raise ArgumentError, "callback redirect URI does not match configuration" unless input.redirect_uri == configuration.redirect_uri

      calls << input
      raise_scenario_error! unless scenario == :success

      identity = Identity::NormalizedIdentity.new(
        provider: provider,
        subject: "#{provider}-stable-subject",
        email: "#{provider}-user@example.test",
        email_verified: true,
        profile: { "name" => "Synthetic #{provider.capitalize} User", "login" => "#{provider}-login" }
      )
      Identity::CallbackExchange.new(identity: identity, oidc_claims: oidc_claims(identity, input))
    end

    private

    def oidc_claims(identity, input)
      return unless configuration.oidc?

      Identity::OidcClaims.new(
        issuer: configuration.issuer.to_s,
        subject: identity.subject,
        audiences: [ configuration.client_id ],
        authorized_party: configuration.client_id,
        issued_at: Time.utc(2026, 9, 4, 3, 0, 0),
        expires_at: Time.utc(2026, 9, 4, 4, 0, 0),
        nonce: input.nonce,
        key_id: "synthetic-key-id",
        algorithm: "RS256"
      )
    end

    def raise_scenario_error!
      raise Identity::ProviderError.new(
        category: scenario.to_s,
        operation: "callback_exchange",
        retry_after: scenario == :rate_limited ? 1.0 : nil
      )
    end
  end

  class GoogleProviderAdapterFake < IdentityProviderAdapterFake
    def initialize(configuration:, **)
      raise ArgumentError, "Google configuration is required" unless configuration.provider == "google"

      super
    end
  end

  class GithubProviderAdapterFake < IdentityProviderAdapterFake
    def initialize(configuration:, **)
      raise ArgumentError, "GitHub configuration is required" unless configuration.provider == "github"

      super
    end
  end
end
