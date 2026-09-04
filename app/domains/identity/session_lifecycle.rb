# frozen_string_literal: true

module Identity
  class SessionLifecycle
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def issue(user:, metadata: SessionMetadata.empty, rotated_from: nil)
      now = @clock.call
      raise InactiveUser unless user.active?

      Session.transaction do
        token = TokenDigest.generate
        session = Session.create!(
          user: user,
          token_digest: TokenDigest.call(token),
          ip_address_digest: metadata.ip_address_digest,
          user_agent_digest: metadata.user_agent_digest,
          client_name: metadata.client_name,
          device_type: metadata.device_type,
          authenticated_at: now,
          last_seen_at: now,
          expires_at: now + SessionPolicy::ABSOLUTE_LIFETIME,
          rotated_from: rotated_from
        )
        Audit.emit(
          "session.issued",
          outcome: "succeeded",
          actor_user_id: user.id,
          target_type: "Session",
          target_id: session.id
        )
        IssuedSession.new(session: session, token: token)
      end
    end

    def authenticate!(token:, metadata: SessionMetadata.empty)
      session = find_session(token)
      status = session.status_at(@clock.call)
      raise_for_status!(status) unless status == :active

      refresh_last_seen(session, metadata)
      session
    rescue Error => error
      Audit.emit("session.rejected", outcome: "denied", reason_code: error.reason_code)
      raise
    end

    def rotate!(session:, metadata: SessionMetadata.empty, reason: "rotated")
      Session.transaction do
        session.lock!
        status = session.status_at(@clock.call)
        raise_for_status!(status) unless status == :active

        revoke_record(session, reason)
        issued = issue(user: session.user, metadata: metadata, rotated_from: session)
        Audit.emit(
          "session.rotated",
          outcome: "succeeded",
          reason_code: reason,
          actor_user_id: issued.session.user_id,
          target_type: "Session",
          target_id: issued.session.id
        )
        issued
      end
    rescue Error => error
      Audit.emit("session.rejected", outcome: "denied", reason_code: error.reason_code)
      raise
    end

    def revoke(session:, reason: "logout")
      Session.transaction do
        session.lock!
        changed = !session.revoked_at?

        revoke_record(session, reason) if changed
        Audit.emit(
          "session.revoked",
          outcome: changed ? "succeeded" : "ignored",
          reason_code: reason,
          actor_user_id: session.user_id,
          target_type: "Session",
          target_id: session.id,
          metadata: { revoke_reason: reason }
        )
        changed
      end
    end

    private

    def find_session(token)
      Session.includes(:user).find_by!(token_digest: TokenDigest.call(token))
    rescue ActiveRecord::RecordNotFound
      raise InvalidSession
    end

    def raise_for_status!(status)
      case status
      when :revoked then raise RevokedSession
      when :expired then raise ExpiredSession
      when :idle_expired then raise ExpiredSession.new(reason_code: "session_idle_expired")
      when :user_inactive then raise InactiveUser
      else raise InvalidSession
      end
    end

    def refresh_last_seen(session, metadata)
      now = @clock.call
      return if session.last_seen_at > now - SessionPolicy::LAST_SEEN_WRITE_INTERVAL

      session.update_columns(
        last_seen_at: now,
        ip_address_digest: metadata.ip_address_digest,
        user_agent_digest: metadata.user_agent_digest,
        client_name: metadata.client_name,
        device_type: metadata.device_type,
        updated_at: now
      )
    end

    def revoke_record(session, reason)
      session.update!(revoked_at: @clock.call, revoke_reason: reason)
    end
  end
end
