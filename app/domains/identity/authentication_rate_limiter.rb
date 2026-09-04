# frozen_string_literal: true

module Identity
  class AuthenticationRateLimiter
    Decision = Data.define(:scope, :allowed, :retry_after, :request_count) do
      def allowed?
        allowed
      end
    end

    def self.from_settings(settings: Rails.application.config.x.searchops)
      new(policy: AuthenticationRateLimitPolicy.from_settings(settings: settings))
    end

    def initialize(policy:, clock: -> { Time.current })
      @policy = policy
      @clock = clock
    end

    def consume!(scope:, key:, now: @clock.call)
      decision = record(scope: scope, key: key, now: now)
      raise_limited!(decision) unless decision.allowed?

      decision
    end

    def ensure_allowed!(scope:, key:, now: @clock.call)
      scope = scope.to_s
      rule = @policy.fetch(scope)
      bucket = current_bucket(scope, key_digest(scope, key), rule, now)
      allowed = bucket.nil? || bucket.request_count < rule.limit
      decision = decision_for(scope, allowed, bucket&.request_count.to_i, window_expiry(now, rule), now)
      emit(decision)
      raise_limited!(decision) unless allowed

      decision
    end

    def record(scope:, key:, now: @clock.call)
      scope = scope.to_s
      rule = @policy.fetch(scope)
      started_at = window_start(now, rule)
      expires_at = started_at + rule.window
      digest = key_digest(scope, key)
      bucket = increment_bucket(scope, digest, started_at, expires_at, now)
      decision = decision_for(scope, bucket.request_count <= rule.limit, bucket.request_count, expires_at, now)
      emit(decision)
      decision
    end

    private

    def increment_bucket(scope, digest, started_at, expires_at, now)
      sql = <<~SQL.squish
        INSERT INTO authentication_rate_limit_buckets
          (scope, key_digest, window_started_at, expires_at, request_count, created_at, updated_at)
        VALUES (?, ?, ?, ?, 1, ?, ?)
        ON CONFLICT (scope, key_digest, window_started_at)
        DO UPDATE SET
          request_count = authentication_rate_limit_buckets.request_count + 1,
          expires_at = GREATEST(authentication_rate_limit_buckets.expires_at, EXCLUDED.expires_at),
          updated_at = EXCLUDED.updated_at
        RETURNING authentication_rate_limit_buckets.*
      SQL
      AuthenticationRateLimitBucket.uncached do
        AuthenticationRateLimitBucket.find_by_sql(
          [ sql, scope, digest, started_at, expires_at, now, now ]
        ).sole
      end
    end

    def current_bucket(scope, digest, rule, now)
      AuthenticationRateLimitBucket.uncached do
        AuthenticationRateLimitBucket.find_by(
          scope: scope,
          key_digest: digest,
          window_started_at: window_start(now, rule)
        )
      end
    end

    def key_digest(scope, key)
      Identity::SecretDigest.call("#{scope}:#{key}", purpose: "auth-rate-limit")
    rescue ArgumentError
      raise ArgumentError, "authentication rate-limit key is invalid"
    end

    def window_start(now, rule)
      seconds = rule.window.to_i
      Time.at((now.to_i / seconds) * seconds).utc
    end

    def window_expiry(now, rule)
      window_start(now, rule) + rule.window
    end

    def decision_for(scope, allowed, count, expires_at, now)
      Decision.new(scope, allowed, [ (expires_at - now).ceil, 1 ].max, count)
    end

    def emit(decision)
      Audit.emit(
        "auth.rate_limit_decision",
        outcome: decision.allowed? ? "succeeded" : "denied",
        operation: decision.scope,
        reason_code: decision.allowed? ? "within_limit" : "rate_limited"
      )
    end

    def raise_limited!(decision)
      raise AuthenticationRateLimited.new(scope: decision.scope, retry_after: decision.retry_after)
    end
  end
end
