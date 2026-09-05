# frozen_string_literal: true

module Crawling
  class RecoverStaleFetchPermits
    BATCH_SIZE = 500

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(limit: BATCH_SIZE)
      batch_size = Integer(limit)
      raise ArgumentError, "fetch permit recovery batch is invalid" unless
        batch_size.between?(1, BATCH_SIZE)

      now = @clock.call
      recovered = []
      FetchPermit.transaction do
        FetchPermit.stale_at(now).order(:expires_at, :id)
          .lock("FOR UPDATE SKIP LOCKED").limit(batch_size).each do |permit|
          permit.update!(
            state: "expired",
            released_at: now,
            release_outcome: "expired",
            failure_category: "permit_expired"
          )
          recovered << permit
        end
      end
      recovered.freeze
    end
  end
end
