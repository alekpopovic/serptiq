# frozen_string_literal: true

module Identity
  class AuthenticationRateLimitCleanupJob < ApplicationJob
    runs_on :maintenance
    system_authorization :authentication_rate_limit_cleanup,
      reason: "deletes expired global authentication rate-limit buckets"

    def perform
      AuthenticationRateLimitCleanup.new.call
    end
  end
end
