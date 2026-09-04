# frozen_string_literal: true

module Identity
  class GoogleAuthorizationStarter
    def self.from_settings(settings: Rails.application.config.x.searchops)
      policy = OauthInitiationPolicy.from_settings(settings: settings)
      new(
        adapter: GoogleProviderAdapter.from_settings(settings: settings),
        limiter: OauthInitiationLimiter.new(policy: policy),
        policy: policy
      )
    end

    def initialize(adapter:, limiter:, policy:, clock: -> { Time.current },
      secret_generator: -> { OauthAuthorizationSecrets.generate })
      raise ArgumentError, "Google adapter is required" unless adapter.provider == "google"

      @adapter = adapter
      @limiter = limiter
      @policy = policy
      @clock = clock
      @secret_generator = secret_generator
    end

    def call(return_to:, link_intent:, current_session:, initiator_digest:)
      now = @clock.call
      link_session = validated_link_session(link_intent, current_session, now)
      secrets = @secret_generator.call
      authorization_request = @adapter.authorization_request(
        state: secrets.state,
        nonce: secrets.nonce,
        code_challenge: secrets.pkce_challenge
      )
      transaction = @limiter.within_limit(
        initiator_digest: initiator_digest,
        link_session: link_session,
        now: now
      ) do
        Public.create_oauth_transaction!(
          provider: "google",
          state: secrets.state,
          nonce: secrets.nonce,
          pkce_verifier: secrets.pkce_verifier,
          initiator_digest: initiator_digest,
          link_session: link_session,
          return_to: return_to,
          expires_at: now + @policy.transaction_ttl
        )
      end
      Audit.emit(
        "auth.oauth_started",
        outcome: "succeeded",
        provider: "google",
        operation: link_session ? "link" : "sign_in"
      )
      AuthorizationStart.new(authorization_request: authorization_request, transaction: transaction)
    rescue OauthInitiationLimited => error
      Audit.emit(
        "auth.oauth_start_rejected",
        outcome: "denied",
        provider: "google",
        reason_code: error.reason_code
      )
      raise
    end

    private

    def validated_link_session(link_intent, current_session, now)
      if link_intent
        raise AuthenticationRequired unless current_session&.status_at(now) == :active
        unless current_session.authenticated_at >= now - SessionPolicy::RECENT_AUTHENTICATION_WINDOW
          raise RecentAuthenticationRequired
        end

        current_session
      elsif current_session
        raise InvalidOauthInitiation.new(reason_code: "oauth_start_existing_session_requires_link_intent")
      end
    end
  end
end
