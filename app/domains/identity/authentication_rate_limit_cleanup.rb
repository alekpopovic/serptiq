# frozen_string_literal: true

module Identity
  class AuthenticationRateLimitCleanup
    BATCH_SIZE = 1_000
    MAX_BATCHES = 10

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call
      deleted = 0
      MAX_BATCHES.times do
        ids = AuthenticationRateLimitBucket.where(expires_at: ..@clock.call)
          .order(:expires_at, :id)
          .limit(BATCH_SIZE)
          .pluck(:id)
        break if ids.empty?

        deleted += AuthenticationRateLimitBucket.where(id: ids).delete_all
      end
      Audit.emit(
        "auth.rate_limit_cleanup_completed",
        outcome: "succeeded",
        operation: "expired_buckets"
      )
      deleted
    end
  end
end
