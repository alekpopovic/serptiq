# frozen_string_literal: true

require "uri"

module Identity
  class GoogleProviderAdapter < ProviderAdapter
    SCOPES = %w[openid email profile].freeze
    TOKEN_TYPE = "Bearer"

    def self.from_settings(settings: Rails.application.config.x.searchops, transport: NetHttpTransport.new,
      sleeper: ->(delay) { sleep(delay) }, clock: -> { Time.current })
      configuration = ProviderConfiguration.from_settings(provider: "google", settings: settings)
      http_client = HttpClient.from_settings(
        configuration: configuration,
        settings: settings,
        transport: transport,
        sleeper: sleeper,
        clock: clock
      )
      jwks_cache = GoogleJwksCache.new(
        fetcher: -> { http_client.get_json(uri: configuration.jwks_endpoint, operation: "jwks") },
        ttl: settings.fetch(:oauth_jwks_cache_ttl),
        max_keys: settings.fetch(:oauth_jwks_max_keys),
        clock: clock
      )
      validator = GoogleIdTokenValidator.new(
        configuration: configuration,
        jwks_cache: jwks_cache,
        clock_skew: settings.fetch(:oauth_oidc_clock_skew),
        max_token_lifetime: settings.fetch(:oauth_oidc_max_token_lifetime),
        clock: clock
      )
      new(
        configuration: configuration,
        client_secret: settings.secret(:oauth_google_client_secret),
        http_client: http_client,
        id_token_validator: validator
      )
    end

    def initialize(configuration:, client_secret: nil, http_client: nil, id_token_validator: nil)
      super(configuration: configuration)
      raise ArgumentError, "Google configuration is required" unless provider == "google"

      @client_secret = client_secret&.to_s&.dup&.freeze
      @http_client = http_client
      @id_token_validator = id_token_validator
    end

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

    def inspect
      "#<#{self.class.name} provider=#{provider.inspect} redirect_uri=#{configuration.redirect_uri.inspect} " \
        "callback_configured=#{@client_secret.present? && @http_client && @id_token_validator ? 'true' : 'false'}>"
    end

    def exchange_callback(input)
      validate_callback_input!(input)
      response = @http_client.post_form_json(
        uri: configuration.token_endpoint,
        operation: "token_exchange",
        form: {
          code: input.code,
          client_id: configuration.client_id,
          client_secret: @client_secret,
          redirect_uri: configuration.redirect_uri.to_s,
          grant_type: "authorization_code",
          code_verifier: input.pkce_verifier
        }
      )
      token = validate_token_response!(response)
      claims, payload = @id_token_validator.call(token: token, callback_input: input)
      identity = normalized_identity(payload)
      unless claims.subject == identity.subject
        raise malformed("google_id_token_subject_mismatch")
      end

      CallbackExchange.new(identity: identity, oidc_claims: claims)
    rescue ProviderError
      raise
    rescue ArgumentError, EncodingError, OpenSSL::OpenSSLError
      raise malformed("google_callback_malformed"), cause: nil
    end

    private

    def validate_callback_input!(input)
      raise ArgumentError, "callback input is required" unless input.is_a?(CallbackInput)
      unless input.redirect_uri == configuration.redirect_uri
        raise ProviderError.new(
          category: "configuration",
          operation: "callback_exchange",
          reason_code: "google_redirect_uri_mismatch"
        )
      end
      unless @client_secret.present? && @http_client && @id_token_validator
        raise ProviderError.new(
          category: "configuration",
          operation: "callback_exchange",
          reason_code: "google_callback_unconfigured"
        )
      end
    end

    def validate_token_response!(response)
      token = response["id_token"]
      valid_token = token.is_a?(String) && token.bytesize.between?(32, GoogleIdTokenValidator::MAX_TOKEN_BYTES)
      valid_type = !response.key?("token_type") || response["token_type"] == TOKEN_TYPE
      raise malformed("google_token_response_invalid") unless valid_token && valid_type && !response.key?("error")

      token
    end

    def normalized_identity(payload)
      email = optional_bounded_string(payload, "email", maximum: 320)
      verified = payload.fetch("email_verified", false)
      raise malformed("google_email_verification_invalid") unless [ true, false ].include?(verified)
      if verified && email.blank?
        raise malformed("google_verified_email_missing")
      end

      NormalizedIdentity.new(
        provider: "google",
        subject: payload.fetch("sub"),
        email: email,
        email_verified: verified,
        profile: {
          "name" => optional_bounded_string(payload, "name", maximum: 160),
          "avatar_url" => optional_bounded_string(payload, "picture", maximum: 2048),
          "locale" => optional_bounded_string(payload, "locale", maximum: 16)
        }.compact
      )
    rescue KeyError
      raise malformed("google_subject_missing"), cause: nil
    end

    def optional_bounded_string(payload, key, maximum:)
      return unless payload.key?(key)

      value = payload[key]
      raise malformed("google_profile_claim_invalid") unless value.is_a?(String) && value.bytesize.between?(1, maximum)

      value
    end

    def malformed(reason_code)
      ProviderError.new(category: "malformed_response", operation: "callback_exchange", reason_code: reason_code)
    end

    def validate_parameter!(value, name)
      return if OauthAuthorizationSecrets::STATE_PATTERN.match?(value.to_s)

      raise ArgumentError, "#{name} is invalid"
    end
  end
end
