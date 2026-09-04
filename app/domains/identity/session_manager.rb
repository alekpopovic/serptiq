# frozen_string_literal: true

module Identity
  class SessionManager
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def inventory(user:, current_session:)
      now = @clock.call
      Session.where(user_id: user.id, revoked_at: nil)
        .where("expires_at > ? AND last_seen_at > ?", now, now - SessionPolicy::IDLE_TIMEOUT)
        .order(last_seen_at: :desc, created_at: :desc)
        .to_a
        .select { |session| session.id == current_session.id || session.active_at?(now) }
        .freeze
    end

    def revoke_other!(session_id:, current_session:)
      Session.transaction do
        now = @clock.call
        current = lock_recent_current!(current_session, now)
        target = Session.lock.find_by(id: session_id, user_id: current.user_id)
        valid = target && target.id != current.id
        raise SessionManagementDenied unless valid

        outcome = SessionLifecycle.new(clock: @clock).revoke(session: target, reason: "administrative")
        Audit.emit(
          "session.management_revocation",
          outcome: outcome ? "succeeded" : "ignored",
          operation: "revoke_other",
          actor_user_id: current.user_id,
          target_type: "Session",
          target_id: session_id
        )
        outcome
      end
    rescue StandardError => error
      emit_rejection("revoke_other", error)
      raise
    end

    def revoke_all_others!(current_session:)
      Session.transaction do
        now = @clock.call
        current = lock_recent_current!(current_session, now)
        count = Session.where(user_id: current.user_id, revoked_at: nil).where.not(id: current.id).update_all(
          revoked_at: now,
          revoke_reason: "administrative",
          updated_at: now
        )
        Audit.emit(
          "session.management_revocation",
          outcome: "succeeded",
          operation: "revoke_all_others",
          actor_user_id: current.user_id,
          target_type: "User",
          target_id: current.user_id,
          metadata: { revoked_count: count }
        )
        count
      end
    rescue StandardError => error
      emit_rejection("revoke_all_others", error)
      raise
    end

    private

    def lock_recent_current!(session, now)
      raise RecentAuthenticationRequired unless session

      current = Session.lock.includes(:user).find(session.id)
      valid = current.active_at?(now) && current.authenticated_at >= now - SessionPolicy::RECENT_AUTHENTICATION_WINDOW
      raise RecentAuthenticationRequired unless valid

      current
    rescue ActiveRecord::RecordNotFound
      raise RecentAuthenticationRequired, cause: nil
    end

    def emit_rejection(operation, error)
      reason_code = error.reason_code if error.respond_to?(:reason_code)
      Audit.emit(
        "session.management_rejected",
        outcome: "denied",
        operation: operation,
        reason_code: reason_code
      )
    end
  end
end
