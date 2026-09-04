# frozen_string_literal: true

module Identity
  class AuthenticationRateLimitCleanupJob < ApplicationJob
    runs_on :maintenance

    def perform
      AuthenticationRateLimitCleanup.new.call
    end
  end
end
