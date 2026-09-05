# frozen_string_literal: true

module Crawling
  class LinkGraphQuery
    BROKEN_STATES = %w[rejected failed exhausted].freeze

    def call(organization_id:, scan_id:)
      scan = Scan.find_by!(organization_id: organization_id, id: scan_id)
      links = CrawlLink.where(organization_id: organization_id, scan_id: scan.id)
      nodes = CrawlUrl.where(scan_id: scan.id, state: "succeeded")
        .joins(:page_snapshot).where(crawl_page_snapshots: { state: "completed" })
      incoming = links.internal.where.not(destination_crawl_url_id: nil)
        .select(:destination_crawl_url_id)
      depth_counts = nodes.group(:depth).count.sort.to_h
      LinkGraphSummary.new(
        scan_id: scan.id,
        node_count: nodes.count,
        internal_edge_count: links.internal.count,
        external_edge_count: links.external.count,
        broken_destination_crawl_url_ids: links.internal
          .joins(:destination_crawl_url)
          .where(crawl_urls: { state: BROKEN_STATES })
          .distinct.order(:destination_crawl_url_id).pluck(:destination_crawl_url_id),
        orphan_crawl_url_ids: nodes.where.not(depth: 0).where.not(id: incoming)
          .order(:id).pluck(:id),
        maximum_internal_depth: depth_counts.keys.max,
        depth_counts: depth_counts
      )
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "link_graph_scope_unavailable"), cause: nil
    end
  end
end
