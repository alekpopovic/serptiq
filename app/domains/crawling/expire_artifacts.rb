# frozen_string_literal: true

module Crawling
  class ExpireArtifacts
    BATCH_SIZE = 250

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(batch_size: BATCH_SIZE)
      now = @clock.call
      Artifact.transaction do
        Artifact.retained.where(legal_hold: false).where(retention_expires_at: ..now)
          .order(:retention_expires_at, :id).limit(Integer(batch_size)).lock("FOR UPDATE SKIP LOCKED").map do |artifact|
            artifact.update!(retention_state: "deletion_pending", deletion_requested_at: now)
            artifact.id
          end
      end.freeze
    end
  end
end
