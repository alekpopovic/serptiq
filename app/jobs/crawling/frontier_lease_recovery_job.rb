# frozen_string_literal: true

module Crawling
  class FrontierLeaseRecoveryJob < ApplicationJob
    runs_on :maintenance
    system_authorization :frontier_lease_recovery,
      reason: "recovers a bounded SKIP LOCKED batch of expired crawl frontier leases"

    def perform
      Public.recover_stale_frontier_leases
    end
  end
end
