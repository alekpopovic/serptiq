# frozen_string_literal: true

module Identity
  class OauthCallbackRateGuard
    SCOPE = "oauth_callback_failure_ip"

    def self.from_settings(settings: Rails.application.config.x.searchops)
      new(limiter: AuthenticationRateLimiter.from_settings(settings: settings))
    end

    def initialize(limiter:)
      @limiter = limiter
    end

    def call(provider:, initiator_digest:)
      @limiter.ensure_allowed!(scope: SCOPE, key: initiator_digest)
      yield
    rescue AuthenticationRateLimited
      raise
    rescue StandardError => error
      AuthenticationFailureMetrics.record(error: error, provider: provider)
      decision = @limiter.record(scope: SCOPE, key: initiator_digest)
      unless decision.allowed?
        raise AuthenticationRateLimited.new(scope: decision.scope, retry_after: decision.retry_after), cause: nil
      end

      raise
    end
  end
end
