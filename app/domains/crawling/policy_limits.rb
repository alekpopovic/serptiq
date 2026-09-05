# frozen_string_literal: true

module Crawling
  PolicyLimits = Data.define(
    :max_urls, :max_depth, :max_concurrency, :max_request_rate,
    :rendering_enabled, :max_rendered_pages, :custom_user_agent,
    :custom_patterns, :artifact_retention_days, :provenance
  ) do
    def initialize(**attributes)
      attributes[:provenance] = attributes.fetch(:provenance).transform_values(&:to_s).freeze
      super(**attributes)
      freeze
    end
  end
end
