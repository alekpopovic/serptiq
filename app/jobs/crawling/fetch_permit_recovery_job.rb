# frozen_string_literal: true

module Crawling
  class FetchPermitRecoveryJob < ApplicationJob
    runs_on :maintenance
    system_authorization :fetch_permit_recovery,
      reason: "expires a bounded SKIP LOCKED batch of stale crawl fetch permits"

    def perform
      Public.recover_stale_fetch_permits
    end
  end
end
