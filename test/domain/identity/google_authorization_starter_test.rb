# frozen_string_literal: true

require "test_helper"

class IdentityGoogleAuthorizationStarterTest < ActiveSupport::TestCase
  test "persists protected one-time material with exact expiry and a safe local return" do
    now = Time.current.change(usec: 0)
    secrets = deterministic_oauth_secrets
    starter = build_google_authorization_starter(
      clock: -> { now },
      secret_generator: -> { secrets }
    )

    start = starter.call(
      return_to: "https://attacker.example/phish",
      link_intent: false,
      current_session: nil,
      initiator_digest: "a" * 64
    )
    transaction = start.transaction.reload

    assert_equal "/dashboard", transaction.return_to
    assert_equal now + 10.minutes, transaction.expires_at
    assert transaction.open_at?(now)
    assert transaction.nonce_matches?(secrets.nonce)
    assert_equal secrets.pkce_verifier, transaction.pkce_verifier
    refute_equal secrets.state, transaction.state_digest
    refute_equal secrets.nonce, transaction.nonce_digest
    refute_equal secrets.pkce_verifier, transaction.pkce_verifier_digest
    refute_includes transaction.attributes.values.map(&:to_s), secrets.state
    refute_includes transaction.attributes.values.map(&:to_s), secrets.nonce
    refute_includes transaction.attributes.values.map(&:to_s), secrets.pkce_verifier
    assert_nil transaction.link_session
    refute transaction.link_intent?
  end

  test "binds explicit linking to an active recently authenticated session" do
    now = Time.current.change(usec: 0)
    issued = issue_identity_session(at: now - 5.minutes)
    starter = build_google_authorization_starter(clock: -> { now })

    start = starter.call(
      return_to: "/dashboard",
      link_intent: true,
      current_session: issued.session,
      initiator_digest: "b" * 64
    )

    assert start.transaction.link_intent?
    assert_equal issued.session, start.transaction.link_session
    assert_equal issued.session.user, start.transaction.link_session.user
  end

  test "rejects anonymous stale revoked and ambiguous existing-session linking attempts" do
    now = Time.current.change(usec: 0)
    starter = build_google_authorization_starter(clock: -> { now })

    assert_raises(Identity::AuthenticationRequired) do
      starter.call(return_to: "/dashboard", link_intent: true, current_session: nil, initiator_digest: "c" * 64)
    end

    stale = issue_identity_session(at: now - Identity::SessionPolicy::RECENT_AUTHENTICATION_WINDOW - 1.second)
    assert_raises(Identity::RecentAuthenticationRequired) do
      starter.call(return_to: "/dashboard", link_intent: true, current_session: stale.session,
        initiator_digest: "d" * 64)
    end

    revoked = issue_identity_session(at: now - 1.minute)
    Identity::Public.revoke_session(session: revoked.session, clock: -> { now })
    assert_raises(Identity::AuthenticationRequired) do
      starter.call(return_to: "/dashboard", link_intent: true, current_session: revoked.session,
        initiator_digest: "e" * 64)
    end

    active = issue_identity_session(at: now - 1.minute)
    assert_raises(Identity::InvalidOauthInitiation) do
      starter.call(return_to: "/dashboard", link_intent: false, current_session: active.session,
        initiator_digest: "f" * 64)
    end
    assert_equal 0, Identity::OauthTransaction.where(initiator_digest: %w[c d e f].map { |letter| letter * 64 }).count
  end

  test "caps outstanding and recent starts and cleans stale retained transactions" do
    now = Time.current.change(usec: 0)
    sequence = 0
    policy = build_oauth_initiation_policy(
      retention: 1.hour,
      max_per_ip: 2,
      max_open_per_ip: 1
    )
    starter = build_google_authorization_starter(
      policy: policy,
      clock: -> { now },
      secret_generator: -> { sequence += 1; deterministic_oauth_secrets(sequence) }
    )

    first = starter.call(
      return_to: "/dashboard", link_intent: false, current_session: nil, initiator_digest: "1" * 64
    )
    outstanding = assert_raises(Identity::OauthInitiationLimited) do
      starter.call(return_to: "/dashboard", link_intent: false, current_session: nil,
        initiator_digest: "1" * 64)
    end
    assert_equal "oauth_start_ip_outstanding_limited", outstanding.reason_code

    first.transaction.update!(consumed_at: now, attempt_count: 1, last_attempted_at: now)
    starter.call(return_to: "/dashboard", link_intent: false, current_session: nil, initiator_digest: "1" * 64)
    rate = assert_raises(Identity::OauthInitiationLimited) do
      starter.call(return_to: "/dashboard", link_intent: false, current_session: nil,
        initiator_digest: "1" * 64)
    end
    assert_equal "oauth_start_ip_rate_limited", rate.reason_code

    stale = create_stale_transaction(now)
    starter.call(return_to: "/dashboard", link_intent: false, current_session: nil, initiator_digest: "2" * 64)
    refute Identity::OauthTransaction.exists?(stale.id)
  end

  test "caps link attempts by session even when the initiator address changes" do
    now = Time.current.change(usec: 0)
    issued = issue_identity_session(at: now - 1.minute)
    sequence = 0
    policy = build_oauth_initiation_policy(max_open_per_session: 1)
    starter = build_google_authorization_starter(
      policy: policy,
      clock: -> { now },
      secret_generator: -> { sequence += 1; deterministic_oauth_secrets(sequence) }
    )

    starter.call(return_to: "/dashboard", link_intent: true, current_session: issued.session,
      initiator_digest: "3" * 64)
    error = assert_raises(Identity::OauthInitiationLimited) do
      starter.call(return_to: "/dashboard", link_intent: true, current_session: issued.session,
        initiator_digest: "4" * 64)
    end

    assert_equal "oauth_start_session_outstanding_limited", error.reason_code
    assert_equal 1, Identity::OauthTransaction.where(link_session: issued.session).count
  end

  private

  def create_stale_transaction(now)
    travel_to(now - 2.hours - 10.minutes) do
      create_oauth_transaction(
        initiator_digest: "9" * 64,
        expires_at: now - 2.hours,
        state: deterministic_oauth_secrets(99).state,
        nonce: deterministic_oauth_secrets(99).nonce,
        pkce_verifier: deterministic_oauth_secrets(99).pkce_verifier
      ).fetch(:transaction)
    end
  end
end
