# frozen_string_literal: true

module Crawling
  class ScanUsageRecoveryJob < ApplicationJob
    runs_on :maintenance
    system_authorization :scan_usage_recovery,
      reason: "finalizes bounded terminal scan reservations and abandoned operation allocations"

    def perform
      Public.recover_terminal_scan_usage
    end
  end
end
