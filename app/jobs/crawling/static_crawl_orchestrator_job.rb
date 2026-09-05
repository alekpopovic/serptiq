# frozen_string_literal: true

module Crawling
  class StaticCrawlOrchestratorJob < ApplicationJob
    runs_on :crawl
    system_authorization :static_crawl_orchestration,
      reason: "executes one bounded unit for an exact admitted tenant scan"

    def perform(organization_id:, scan_id:)
      Public.orchestrate_static_crawl(
        organization_id: organization_id,
        scan_id: scan_id,
        worker_id: "crawl-#{job_id}"
      )
    end
  end
end
