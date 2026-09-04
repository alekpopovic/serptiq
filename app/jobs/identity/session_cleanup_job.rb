# frozen_string_literal: true

module Identity
  class SessionCleanupJob < ApplicationJob
    runs_on :maintenance
    system_authorization :session_cleanup,
      reason: "expires global identity sessions according to the retention policy"

    def perform
      SessionCleanup.new.call
    end
  end
end
