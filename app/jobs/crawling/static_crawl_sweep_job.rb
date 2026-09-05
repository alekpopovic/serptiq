# frozen_string_literal: true

module Crawling
  class StaticCrawlSweepJob < ApplicationJob
    runs_on :maintenance
    system_authorization :static_crawl_recovery,
      reason: "recovers bounded stale initialization and extraction work and resumes exact tenant scans"

    def perform
      Public.recover_static_crawl_work
    end
  end
end
