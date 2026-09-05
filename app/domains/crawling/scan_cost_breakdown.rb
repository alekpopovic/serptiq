# frozen_string_literal: true

module Crawling
  ScanCostBreakdown = Data.define(
    :scan_id, :estimated_credits, :gross_credits, :net_credits,
    :reserved_credits, :released_credits, :entries
  ) do
    def initialize(**attributes)
      attributes[:scan_id] = attributes.fetch(:scan_id).to_s.dup.freeze
      attributes[:entries] = attributes.fetch(:entries).freeze
      super(**attributes)
      freeze
    end
  end
end
