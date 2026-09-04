# frozen_string_literal: true

require "uri"

module Identity
  class GithubProviderAdapter < ProviderAdapter
    SCOPES = %w[read:user user:email].freeze
    API_VERSION = "2026-03-10"
    ACCESS_TOKEN_PATTERN = /\A\S{16,2048}\z/
    LOGIN_PATTERN = /\A[!-~]{1,255}\z/
    MAX_EMAILS = 100

    def self.from_settings(settings: Rails.application.config.x.searchops, transport: NetHttpTransport.new,
      sleeper: ->(delay) { sleep(delay) }, clock: -> { Time.current })
      configuration = ProviderConfiguration.from_settings(provider: "github", settings: settings)
      new(
        configuration: configuration,
        client_secret: settings.secret(:oauth_github_client_secret),
        http_client: HttpClient.from_settings(
          configuration: configuration,
          settings: settings,
          transport: transport,
          sleeper: sleeper,
          clock: clock
        )
      )
    end

    def initialize(configuration:, client_secret: nil, http_client: nil)
      super(configuration: configuration)
      raise ArgumentError, "GitHub configuration is required" unless provider == "github"

      @client_secret = client_secret&.to_s&.dup&.freeze
      @http_client = http_client
    end

    def authorization_request(state:, code_challenge:, nonce: nil)
      validate_parameter!(state, "state")
      validate_parameter!(code_challenge, "PKCE challenge")
      raise ArgumentError, "GitHub OAuth does not accept an OIDC nonce" if nonce

      uri = configuration.authorization_endpoint.dup
      uri.query = URI.encode_www_form(
        client_id: configuration.client_id,
        redirect_uri: configuration.redirect_uri.to_s,
        scope: SCOPES.join(" "),
        state: state,
        code_challenge: code_challenge,
        code_challenge_method: "S256"
      )
      AuthorizationRequest.new(provider: provider, uri: uri)
    end

    def exchange_callback(input)
      validate_callback_input!(input)
      token_response = @http_client.post_form_json(
        uri: configuration.token_endpoint,
        operation: "token_exchange",
        headers: { "Accept" => "application/json" },
        form: {
          client_id: configuration.client_id,
          client_secret: @client_secret,
          code: input.code,
          redirect_uri: configuration.redirect_uri.to_s,
          code_verifier: input.pkce_verifier
        }
      )
      access_token, scopes = access_token_from(token_response)
      profile = @http_client.get_json(
        uri: configuration.user_endpoint,
        operation: "userinfo",
        headers: api_headers(access_token)
      )
      id, login = validate_user_profile!(profile)
      email, email_verified = email_observation(profile, access_token, scopes)
      CallbackExchange.new(
        identity: normalized_identity(
          profile,
          id: id,
          login: login,
          email: email,
          email_verified: email_verified
        )
      )
    rescue ProviderError
      raise
    rescue ArgumentError, EncodingError
      raise malformed("github_callback_malformed"), cause: nil
    end

    def inspect
      "#<#{self.class.name} provider=#{provider.inspect} redirect_uri=#{configuration.redirect_uri.inspect} " \
        "callback_configured=#{@client_secret.present? && @http_client ? 'true' : 'false'}>"
    end

    private

    def validate_callback_input!(input)
      raise ArgumentError, "callback input is required" unless input.is_a?(CallbackInput)
      raise ArgumentError, "GitHub OAuth callback cannot contain an OIDC nonce" if input.nonce || input.nonce_digest
      unless input.redirect_uri == configuration.redirect_uri
        raise ProviderError.new(
          category: "configuration",
          operation: "callback_exchange",
          reason_code: "github_redirect_uri_mismatch"
        )
      end
      unless @client_secret.present? && @http_client
        raise ProviderError.new(
          category: "configuration",
          operation: "callback_exchange",
          reason_code: "github_callback_unconfigured"
        )
      end
    end

    def access_token_from(response)
      map_token_error!(response["error"]) if response.key?("error")
      access_token = response["access_token"]
      token_type = response["token_type"]
      scope = response.fetch("scope", "")
      valid = ACCESS_TOKEN_PATTERN.match?(access_token.to_s) && token_type.is_a?(String) &&
        token_type.casecmp?("bearer") && scope.is_a?(String) && scope.bytesize <= 2048
      raise malformed("github_token_response_invalid") unless valid

      [ access_token, scope.split(/[,\s]+/).reject(&:empty?).uniq.freeze ]
    end

    def map_token_error!(value)
      case value
      when "incorrect_client_credentials"
        raise ProviderError.new(
          category: "credentials_revoked",
          operation: "token_exchange",
          reason_code: "github_client_credentials_rejected"
        )
      when "bad_verification_code", "expired_verification_code"
        raise ProviderError.new(
          category: "access_denied",
          operation: "token_exchange",
          reason_code: "github_authorization_code_rejected"
        )
      when "redirect_uri_mismatch"
        raise ProviderError.new(
          category: "configuration",
          operation: "token_exchange",
          reason_code: "github_provider_redirect_mismatch"
        )
      else
        raise malformed("github_token_error_unknown")
      end
    end

    def email_observation(profile, access_token, scopes)
      public_email = optional_string(profile, "email", maximum: 320)
      return [ public_email, false ] unless scopes.include?("user:email")

      emails = @http_client.get_json_array(
        uri: configuration.emails_endpoint,
        operation: "email_lookup",
        headers: api_headers(access_token),
        max_items: MAX_EMAILS
      )
      entries = emails.map { |entry| normalize_email_entry(entry) }
      primary = entries.select { |entry| entry.fetch(:primary) }
      raise malformed("github_primary_email_ambiguous") if primary.length > 1

      selected = primary.first
      selected ? [ selected.fetch(:email), selected.fetch(:verified) ] : [ public_email, false ]
    end

    def normalize_email_entry(entry)
      email = entry["email"]
      verified = entry["verified"]
      primary = entry["primary"]
      visibility = entry["visibility"]
      valid = email.is_a?(String) && email.bytesize.between?(3, 320) &&
        URI::MailTo::EMAIL_REGEXP.match?(email) && [ true, false ].include?(verified) &&
        [ true, false ].include?(primary) && [ nil, "public", "private" ].include?(visibility)
      raise malformed("github_email_response_invalid") unless valid

      { email: email.downcase.freeze, verified: verified, primary: primary }.freeze
    end

    def validate_user_profile!(profile)
      id = profile["id"]
      login = profile["login"]
      type = profile["type"]
      unless id.is_a?(Integer) && id.positive? && id <= (2**63) - 1 &&
          LOGIN_PATTERN.match?(login.to_s) && type == "User"
        raise malformed("github_user_response_invalid")
      end

      [ id, login ]
    end

    def normalized_identity(profile, id:, login:, email:, email_verified:)
      NormalizedIdentity.new(
        provider: "github",
        subject: id.to_s,
        email: email,
        email_verified: email_verified,
        profile: {
          "login" => login,
          "name" => optional_string(profile, "name", maximum: 160),
          "avatar_url" => optional_string(profile, "avatar_url", maximum: 2048)
        }.compact
      )
    end

    def optional_string(payload, key, maximum:)
      return unless payload.key?(key) && !payload[key].nil?

      value = payload[key]
      raise malformed("github_profile_field_invalid") unless value.is_a?(String) && value.bytesize.between?(1, maximum)

      value
    end

    def api_headers(access_token)
      {
        "Accept" => "application/vnd.github+json",
        "Authorization" => "Bearer #{access_token}",
        "X-GitHub-Api-Version" => API_VERSION
      }
    end

    def validate_parameter!(value, name)
      return if OauthAuthorizationSecrets::STATE_PATTERN.match?(value.to_s)

      raise ArgumentError, "#{name} is invalid"
    end

    def malformed(reason_code)
      ProviderError.new(category: "malformed_response", operation: "callback_exchange", reason_code: reason_code)
    end
  end
end
