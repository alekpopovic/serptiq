# frozen_string_literal: true

module Tenancy
  class ExpireInvitations
    BATCH_SIZE = 1_000

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call
      now = @clock.call
      total = 0
      loop do
        ids = Invitation.where(status: "pending", expires_at: ..now).order(:expires_at).limit(BATCH_SIZE).pluck(:id)
        break if ids.empty?

        total += Invitation.where(id: ids, status: "pending").update_all(
          status: "expired", expired_at: now, updated_at: now
        )
      end
      Audit.emit("invitation.expiration_completed", outcome: "succeeded", operation: "expire")
      total
    end
  end
end
