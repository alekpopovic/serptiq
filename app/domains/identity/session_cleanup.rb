# frozen_string_literal: true

module Identity
  class SessionCleanup
    BATCH_SIZE = 500
    MAX_BATCHES = 20

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call
      cutoff = @clock.call - SessionPolicy::RETENTION_AFTER_INACTIVE
      deleted = 0

      MAX_BATCHES.times do
        ids = eligible(cutoff).limit(BATCH_SIZE).pluck(:id)
        break if ids.empty?

        deleted += Session.where(id: ids).delete_all
      end
      Audit.emit("session.cleanup_completed", outcome: "succeeded", operation: "cleanup")
      deleted
    end

    private

    def eligible(cutoff)
      Session.where(
        "sessions.revoked_at < :cutoff OR (sessions.revoked_at IS NULL AND sessions.expires_at < :cutoff)",
        cutoff: cutoff
      )
        .where.missing(:rotations)
        .where.missing(:link_oauth_transactions)
        .order(:id)
    end
  end
end
