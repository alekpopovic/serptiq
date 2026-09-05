# frozen_string_literal: true

module Crawling
  class ScanDispatchJob < ApplicationJob
    runs_on :crawl
    system_authorization :scan_dispatch,
      reason: "queues one admitted tenant scan after validating its durable quota reservation"

    def perform(organization_id:, scan_id:)
      scan = Public.dispatch_scan(organization_id: organization_id, scan_id: scan_id)
      return unless scan&.status.in?(%w[queued running])

      StaticCrawlOrchestratorJob.perform_later(
        organization_id: scan.organization_id,
        scan_id: scan.id
      )
    end
  end
end
