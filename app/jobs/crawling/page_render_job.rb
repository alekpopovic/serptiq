# frozen_string_literal: true

module Crawling
  class PageRenderJob < ApplicationJob
    runs_on :render
    system_authorization :page_render,
      reason: "renders one exact tenant page snapshot in the isolated browser worker"

    def perform(organization_id:, scan_id:, page_render_id:)
      Public.render_page(
        organization_id: organization_id,
        scan_id: scan_id,
        page_render_id: page_render_id,
        worker_id: "render-#{job_id}"
      )
      scan = Public.conclude_static_crawl(organization_id: organization_id, scan_id: scan_id)
      ScanLiveUpdate.new.call(organization_id: organization_id, scan_id: scan_id, force: scan.terminal?)
    end
  end
end
