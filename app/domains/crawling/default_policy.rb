# frozen_string_literal: true

module Crawling
  class DefaultPolicy
    def call(origin:, limits:)
      PolicyConfiguration.new(
        start_urls: [ "#{origin.origin}/" ],
        sitemap_urls: [],
        include_patterns: [],
        exclude_patterns: [],
        max_urls: limits.max_urls,
        max_depth: [ 5, limits.max_depth ].min,
        query_handling: "tracking_only",
        user_agent_suffix: nil,
        request_rate_per_second: [ BigDecimal("2.0"), limits.max_request_rate ].min,
        max_concurrency: [ 1, limits.max_concurrency ].min,
        robots_behavior: "respect",
        rendering_sample_percent: 0,
        max_rendered_pages: 0,
        artifact_retention_days: limits.artifact_retention_days
      )
    end
  end
end
