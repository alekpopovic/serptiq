# frozen_string_literal: true

module Crawling
  class ScanDispatchJob < ApplicationJob
    runs_on :crawl
    system_authorization :scan_dispatch,
      reason: "queues one admitted tenant scan after validating its durable quota reservation"

    def perform(organization_id:, scan_id:)
      Public.dispatch_scan(organization_id: organization_id, scan_id: scan_id)
    end
  end
end
