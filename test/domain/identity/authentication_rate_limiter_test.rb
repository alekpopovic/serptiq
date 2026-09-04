# frozen_string_literal: true

require "test_helper"

class IdentityAuthenticationRateLimiterTest < ActiveSupport::TestCase
  test "uses a keyed digest and a fixed expiring window without resetting on success" do
    now = Time.current.change(usec: 0)
    policy = policy_for("oauth_callback_failure_ip", limit: 2, window: 1.minute)
    limiter = Identity::AuthenticationRateLimiter.new(policy: policy, clock: -> { now })
    private_key = "198.51.100.10:#{'private-material' * 3}"

    first = limiter.record(scope: "oauth_callback_failure_ip", key: private_key)
    guard = Identity::OauthCallbackRateGuard.new(limiter: limiter)
    success = guard.call(provider: "google", initiator_digest: private_key) { :succeeded }
    second = limiter.record(scope: "oauth_callback_failure_ip", key: private_key)

    assert first.allowed?
    assert_equal :succeeded, success
    assert second.allowed?
    bucket = Identity::AuthenticationRateLimitBucket.sole
    assert_equal 2, bucket.request_count
    assert_match(/\A[0-9a-f]{64}\z/, bucket.key_digest)
    refute_equal private_key, bucket.key_digest

    error = assert_raises(Identity::AuthenticationRateLimited) do
      limiter.ensure_allowed!(scope: "oauth_callback_failure_ip", key: private_key)
    end
    assert_equal "oauth_callback_failure_ip", error.scope
    assert_includes 1..60, error.retry_after

    now += 1.minute
    assert limiter.consume!(scope: "oauth_callback_failure_ip", key: private_key).allowed?
    assert_equal 2, Identity::AuthenticationRateLimitBucket.count
  end

  test "OAuth link initiation is capped by exact session when the address changes" do
    now = Time.current.change(usec: 0)
    issued = issue_identity_session(at: now - 1.minute)
    sequence = 0
    oauth_policy = build_oauth_initiation_policy(
      max_per_session: 1,
      max_open_per_session: 2
    )
    starter = build_google_authorization_starter(
      policy: oauth_policy,
      clock: -> { now },
      secret_generator: -> { sequence += 1; deterministic_oauth_secrets(sequence) }
    )
    first = starter.call(
      return_to: "/dashboard",
      link_intent: true,
      current_session: issued.session,
      initiator_digest: "a" * 64
    )
    first.transaction.update!(consumed_at: now, attempt_count: 1, last_attempted_at: now)

    error = assert_raises(Identity::OauthInitiationLimited) do
      starter.call(
        return_to: "/dashboard",
        link_intent: true,
        current_session: issued.session,
        initiator_digest: "b" * 64
      )
    end

    assert_equal "oauth_link_session_rate_limited", error.reason_code
    assert_equal 1, Identity::OauthTransaction.where(link_session: issued.session).count
  end

  test "rejects unsupported scopes policies and unbounded key material" do
    assert_raises(ArgumentError) do
      policy_for("customer_email", limit: 2, window: 1.minute)
    end

    limiter = Identity::AuthenticationRateLimiter.new(
      policy: policy_for("session_action_session", limit: 2, window: 1.minute)
    )
    assert_raises(ArgumentError) do
      limiter.consume!(scope: "session_action_session", key: "x" * 2_000)
    end
  end

  private

  def policy_for(scope, limit:, window:)
    Identity::AuthenticationRateLimitPolicy.new(
      rules: { scope => Identity::AuthenticationRateLimitPolicy::Rule.new(limit, window) }
    )
  end
end
