# frozen_string_literal: true

require "uri"

module Identity
  class GoogleProviderAdapter < ProviderAdapter
    SCOPES = %w[openid email profile].freeze

    def authorization_request(state:, nonce:, code_challenge:)
      validate_parameter!(state, "state")
      validate_parameter!(nonce, "nonce")
      validate_parameter!(code_challenge, "PKCE challenge")

      uri = configuration.authorization_endpoint.dup
      uri.query = URI.encode_www_form(
        client_id: configuration.client_id,
        redirect_uri: configuration.redirect_uri.to_s,
        response_type: "code",
        scope: SCOPES.join(" "),
        state: state,
        nonce: nonce,
        code_challenge: code_challenge,
        code_challenge_method: "S256"
      )
      AuthorizationRequest.new(provider: provider, uri: uri)
    end

    def exchange_callback(_input)
      raise ProviderError.new(
        category: "configuration",
        operation: "callback_exchange",
        reason_code: "google_callback_not_implemented"
      )
    end

    private

    def validate_parameter!(value, name)
      return if OauthAuthorizationSecrets::STATE_PATTERN.match?(value.to_s)

      raise ArgumentError, "#{name} is invalid"
    end
  end
end
