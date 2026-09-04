# frozen_string_literal: true

require "test_helper"

class IdentitySessionLifecycleTest < ActiveSupport::TestCase
  test "issues an opaque token while persisting only its keyed digest and safe metadata" do
    raw_ip = "203.0.113.42"
    raw_agent = "Synthetic Browser/1.0"
    metadata = Identity::SessionMetadata.new(ip_address: raw_ip, user_agent: raw_agent, key: "m" * 32)

    issued = issue_identity_session(metadata: metadata)
    persisted = issued.session.reload

    assert_match Identity::TokenDigest::TOKEN_PATTERN, issued.token
    assert_equal 64, persisted.token_digest.length
    refute_equal issued.token, persisted.token_digest
    assert_equal 64, persisted.ip_address_digest.length
    assert_equal 64, persisted.user_agent_digest.length
    assert_equal persisted.last_seen_at, persisted.authenticated_at
    refute_includes persisted.attributes.values.compact.map(&:to_s), raw_ip
    refute_includes persisted.attributes.values.compact.map(&:to_s), raw_agent
    assert_includes issued.inspect, "token=[FILTERED]"
    refute_includes issued.inspect, issued.token
  end

  test "looks up an active session and periodically persists last seen metadata" do
    started_at = Time.zone.parse("2026-09-04 08:00:00")
    issued = issue_identity_session(at: started_at)
    metadata = Identity::SessionMetadata.new(
      ip_address: "198.51.100.9",
      user_agent: "Later Browser",
      key: "m" * 32
    )

    found = Identity::Public.authenticate_session!(
      token: issued.token,
      metadata: metadata,
      clock: -> { started_at + 10.minutes }
    )

    assert_equal issued.session.id, found.id
    assert_equal started_at + 10.minutes, found.reload.last_seen_at
    assert_equal metadata.ip_address_digest, found.ip_address_digest
    assert_equal metadata.user_agent_digest, found.user_agent_digest
  end

  test "rejects malformed expired idle and revoked sessions with stable domain errors" do
    started_at = Time.zone.parse("2026-09-04 08:00:00")
    malformed = assert_raises(Identity::InvalidSession) do
      Identity::Public.authenticate_session!(token: "not-a-session-token")
    end
    assert_equal "session_invalid", malformed.reason_code

    absolute = issue_identity_session(at: started_at)
    assert_raises(Identity::ExpiredSession) do
      Identity::Public.authenticate_session!(
        token: absolute.token,
        clock: -> { started_at + Identity::SessionPolicy::ABSOLUTE_LIFETIME }
      )
    end

    idle = issue_identity_session(at: started_at)
    idle_error = assert_raises(Identity::ExpiredSession) do
      Identity::Public.authenticate_session!(
        token: idle.token,
        clock: -> { started_at + Identity::SessionPolicy::IDLE_TIMEOUT + 1.second }
      )
    end
    assert_equal "session_idle_expired", idle_error.reason_code

    revoked = issue_identity_session(at: started_at)
    assert Identity::Public.revoke_session(session: revoked.session, clock: -> { started_at + 1.minute })
    assert_raises(Identity::RevokedSession) do
      Identity::Public.authenticate_session!(token: revoked.token, clock: -> { started_at + 2.minutes })
    end
  end

  test "rotation defeats fixation by revoking the old token and issuing a different token" do
    started_at = Time.zone.parse("2026-09-04 08:00:00")
    original = issue_identity_session(at: started_at)

    rotated = Identity::Public.rotate_session!(
      session: original.session,
      clock: -> { started_at + 1.minute }
    )

    assert_not_equal original.token, rotated.token
    assert_not_equal original.session.token_digest, rotated.session.token_digest
    assert_equal original.session.id, rotated.session.rotated_from_id
    assert_equal "rotated", original.session.reload.revoke_reason
    assert_raises(Identity::RevokedSession) do
      Identity::Public.authenticate_session!(token: original.token, clock: -> { started_at + 2.minutes })
    end
    assert_equal rotated.session.id, Identity::Public.authenticate_session!(
      token: rotated.token,
      clock: -> { started_at + 2.minutes }
    ).id
  end

  test "inactive users cannot receive or reuse sessions" do
    suspended_user = create_identity_user(suspended_at: Time.current)

    issue_error = assert_raises(Identity::InactiveUser) do
      issue_identity_session(user: suspended_user)
    end
    assert_equal "user_inactive", issue_error.reason_code

    active_user = create_identity_user
    issued = issue_identity_session(user: active_user)
    active_user.update!(suspended_at: Time.current)

    assert_raises(Identity::InactiveUser) do
      Identity::Public.authenticate_session!(token: issued.token)
    end
  end

  test "model and database reject authentication timestamps after last seen" do
    session = issue_identity_session.session
    session.authenticated_at = session.last_seen_at + 1.second

    refute session.valid?
    assert_includes session.errors[:authenticated_at], "must be at or before last seen"
    error = assert_raises(ActiveRecord::StatementInvalid) do
      Identity::Session.transaction(requires_new: true) { session.save!(validate: false) }
    end
    assert_kind_of PG::CheckViolation, error.cause
  ensure
    session&.reload
  end

  test "security events never contain the raw token or request metadata" do
    output = StringIO.new
    previous_emitter = Shared::Observability.emitter
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(
      logger: ActiveSupport::Logger.new(output)
    )
    metadata = Identity::SessionMetadata.new(
      ip_address: "192.0.2.44",
      user_agent: "Private Agent Value",
      key: "m" * 32
    )

    issued = issue_identity_session(metadata: metadata)
    Identity::Public.revoke_session(session: issued.session)

    assert_includes output.string, "session.issued"
    assert_includes output.string, "session.revoked"
    refute_includes output.string, issued.token
    refute_includes output.string, "192.0.2.44"
    refute_includes output.string, "Private Agent Value"
  ensure
    Shared::Observability.emitter = previous_emitter
  end
end
