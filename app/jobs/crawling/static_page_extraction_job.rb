# frozen_string_literal: true

module Crawling
  class StaticPageExtractionJob < ApplicationJob
    runs_on :analysis
    system_authorization :static_page_extraction,
      reason: "extracts bounded link discovery from one exact tenant page snapshot"

    def perform(organization_id:, scan_id:, page_snapshot_id:)
      Public.extract_static_page_links(
        organization_id: organization_id,
        scan_id: scan_id,
        page_snapshot_id: page_snapshot_id,
        worker_id: "extract-#{job_id}"
      )
      scan = Public.conclude_static_crawl(
        organization_id: organization_id,
        scan_id: scan_id
      )
      ScanLiveUpdate.new.call(
        organization_id: organization_id,
        scan_id: scan_id,
        force: scan.terminal?
      )
      StaticCrawlOrchestratorJob.perform_later(
        organization_id: organization_id,
        scan_id: scan_id
      ) if scan.status == "running" && CrawlUrl.where(
        scan_id: scan_id, state: "pending", next_attempt_at: ..Time.current
      ).exists?
    end
  end
end
