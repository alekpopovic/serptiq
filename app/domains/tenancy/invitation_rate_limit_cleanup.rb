# frozen_string_literal: true

module Tenancy
  class InvitationRateLimitCleanup
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call
      InvitationRateLimitBucket.where(expires_at: ..@clock.call).delete_all
    end
  end
end
