# frozen_string_literal: true

module Identity
  class SessionRiskResponse
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def after_identity_change!(current_session:, metadata: SessionMetadata.empty)
      rotate_only(current_session, metadata, "identity_change")
    end

    def after_ownership_transfer!(current_session:, metadata: SessionMetadata.empty)
      rotate_and_revoke_others(current_session, metadata, "ownership_transfer")
    end

    def after_sensitive_role_change!(current_session:, metadata: SessionMetadata.empty)
      rotate_and_revoke_others(current_session, metadata, "sensitive_role_change")
    end

    def after_suspected_compromise!(user:)
      count = Session.transaction do
        now = @clock.call
        Session.where(user_id: user.id, revoked_at: nil).update_all(
          revoked_at: now,
          revoke_reason: "administrative",
          updated_at: now
        )
      end
      Audit.emit(
        "session.risk_response_completed",
        outcome: "succeeded",
        operation: "suspected_compromise"
      )
      count
    end

    def after_membership_deactivation!(user_id:)
      now = @clock.call
      count = Session.where(user_id: user_id, revoked_at: nil).update_all(
        revoked_at: now,
        revoke_reason: "privilege_changed",
        updated_at: now
      )
      Audit.emit(
        "session.risk_response_completed",
        outcome: "succeeded",
        operation: "membership_deactivation"
      )
      count
    end

    private

    def rotate_only(current_session, metadata, operation)
      issued = SessionLifecycle.new(clock: @clock).rotate!(
        session: current_session,
        metadata: metadata,
        reason: "privilege_changed"
      )
      emit_rotated(operation)
      issued
    end

    def rotate_and_revoke_others(current_session, metadata, operation)
      issued = Session.transaction do
        current = Session.lock.find(current_session.id)
        raise SessionManagementDenied unless current.user_id == current_session.user_id

        now = @clock.call
        Session.where(user_id: current.user_id, revoked_at: nil).where.not(id: current.id).update_all(
          revoked_at: now,
          revoke_reason: "privilege_changed",
          updated_at: now
        )
        SessionLifecycle.new(clock: @clock).rotate!(
          session: current,
          metadata: metadata,
          reason: "privilege_changed"
        )
      end
      emit_rotated(operation)
      issued
    rescue ActiveRecord::RecordNotFound
      raise SessionManagementDenied, cause: nil
    end

    def emit_rotated(operation)
      Audit.emit(
        "session.risk_response_completed",
        outcome: "succeeded",
        operation: operation
      )
    end
  end
end
