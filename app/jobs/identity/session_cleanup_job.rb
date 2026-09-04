# frozen_string_literal: true

module Identity
  class SessionCleanupJob < ApplicationJob
    runs_on :maintenance

    def perform
      SessionCleanup.new.call
    end
  end
end
