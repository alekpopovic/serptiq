# frozen_string_literal: true

module Crawling
  LinkGraphSummary = Data.define(
    :scan_id, :node_count, :internal_edge_count, :external_edge_count,
    :broken_destination_crawl_url_ids, :orphan_crawl_url_ids,
    :maximum_internal_depth, :depth_counts
  ) do
    def initialize(**attributes)
      attributes[:broken_destination_crawl_url_ids] =
        Array(attributes.fetch(:broken_destination_crawl_url_ids)).freeze
      attributes[:orphan_crawl_url_ids] = Array(attributes.fetch(:orphan_crawl_url_ids)).freeze
      attributes[:depth_counts] = attributes.fetch(:depth_counts).to_h.freeze
      super(**attributes)
      freeze
    end
  end
end
