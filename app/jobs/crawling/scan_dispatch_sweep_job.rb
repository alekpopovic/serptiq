# frozen_string_literal: true

module Crawling
  class ScanDispatchSweepJob < ApplicationJob
    runs_on :maintenance
    system_authorization :scan_dispatch_sweep,
      reason: "recovers admitted tenant scans whose post-commit queue handoff did not complete"

    def perform
      Public.schedule_pending_dispatches
    end
  end
end
