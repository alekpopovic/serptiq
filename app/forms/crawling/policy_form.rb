# frozen_string_literal: true

module Crawling
  class PolicyForm
    include ActiveModel::Model

    attr_accessor :start_urls, :sitemap_urls, :include_patterns, :exclude_patterns,
      :max_urls, :max_depth, :query_handling, :user_agent_suffix,
      :request_rate_per_second, :max_concurrency, :robots_behavior,
      :rendering_sample_percent, :max_rendered_pages, :artifact_retention_days

    def self.from_configuration(configuration)
      new(
        **configuration.to_h.except(
          :start_urls, :sitemap_urls, :include_patterns, :exclude_patterns
        ),
        start_urls: configuration.start_urls.join("\n"),
        sitemap_urls: configuration.sitemap_urls.join("\n"),
        include_patterns: configuration.include_patterns.join("\n"),
        exclude_patterns: configuration.exclude_patterns.join("\n")
      )
    end

    def apply_errors(field_errors)
      field_errors.each do |field, messages|
        Array(messages).each { |message| errors.add(field, message) }
      end
      self
    end
  end
end
