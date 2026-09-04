# frozen_string_literal: true

require "digest"

module Identity
  class IdentityUnlinker
    LOCK_NAMESPACE = "searchops:identity:unlink:v1"

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(identity_id:, current_session:, metadata: SessionMetadata.empty)
      result = ProviderIdentity.transaction do
        now = @clock.call
        session = lock_recent_session!(current_session, now)
        advisory_lock(session.user_id)
        identities = ProviderIdentity.where(user_id: session.user_id).order(:id).lock.to_a
        identity = identities.find { |candidate| candidate.id == identity_id.to_s && candidate.active? }
        raise InvalidAccountLink.new(reason_code: "provider_identity_unlink_invalid") unless identity
        raise LastSignInIdentity unless identities.count(&:active?) > 1

        identity.update!(revoked_at: now)
        issued = SessionLifecycle.new(clock: @clock).rotate!(
          session: session,
          metadata: metadata,
          reason: "privilege_changed"
        )
        IdentityUnlink.new(provider: identity.provider, issued_session: issued)
      end
      Audit.emit("auth.identity_unlinked", outcome: "succeeded", provider: result.provider, operation: "unlink")
      result
    rescue StandardError => error
      Audit.emit(
        "auth.identity_unlink_rejected",
        outcome: "denied",
        operation: "unlink",
        reason_code: safe_reason_code(error)
      )
      raise
    end

    private

    def lock_recent_session!(session, now)
      raise RecentAuthenticationRequired unless session

      locked = Session.lock.includes(:user).find(session.id)
      active = locked.status_at(now) == :active && locked.user.active?
      recent = active && locked.authenticated_at >= now - SessionPolicy::RECENT_AUTHENTICATION_WINDOW
      raise RecentAuthenticationRequired unless recent

      locked
    rescue ActiveRecord::RecordNotFound
      raise RecentAuthenticationRequired, cause: nil
    end

    def advisory_lock(user_id)
      digest = Digest::SHA256.digest("#{LOCK_NAMESPACE}:#{user_id}")
      key = digest.unpack1("q>")
      bind = ActiveRecord::Relation::QueryAttribute.new(
        "advisory_lock_key",
        key,
        ActiveRecord::Type::Integer.new(limit: 8)
      )
      ActiveRecord::Base.connection.exec_query(
        "SELECT pg_advisory_xact_lock($1::bigint)::text AS locked",
        "Provider identity unlink advisory lock",
        [ bind ]
      )
    end

    def safe_reason_code(error)
      error.reason_code if error.respond_to?(:reason_code)
    end
  end
end
