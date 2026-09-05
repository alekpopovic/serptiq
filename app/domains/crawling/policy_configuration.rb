# frozen_string_literal: true

module Crawling
  PolicyConfiguration = Data.define(
    :start_urls, :sitemap_urls, :include_patterns, :exclude_patterns,
    :max_urls, :max_depth, :query_handling, :user_agent_suffix,
    :request_rate_per_second, :max_concurrency, :robots_behavior,
    :rendering_sample_percent, :max_rendered_pages, :artifact_retention_days
  ) do
    def self.attribute_keys
      members
    end

    def self.from_record(record)
      new(**attribute_keys.to_h { |key| [ key, record.public_send(key) ] })
    end

    def initialize(**attributes)
      %i[start_urls sitemap_urls include_patterns exclude_patterns].each do |key|
        attributes[key] = Array(attributes.fetch(key)).map { |value| value.to_s.freeze }.freeze
      end
      attributes[:query_handling] = attributes.fetch(:query_handling).to_s.freeze
      attributes[:robots_behavior] = attributes.fetch(:robots_behavior).to_s.freeze
      suffix = attributes[:user_agent_suffix].presence
      attributes[:user_agent_suffix] = suffix&.to_s&.freeze
      attributes[:request_rate_per_second] = BigDecimal(
        attributes.fetch(:request_rate_per_second).to_s
      )
      super(**attributes)
      freeze
    end

    def to_record_attributes
      to_h
    end

    def as_json(*)
      {
        "start_urls" => start_urls,
        "sitemap_urls" => sitemap_urls,
        "include_patterns" => include_patterns,
        "exclude_patterns" => exclude_patterns,
        "max_urls" => max_urls,
        "max_depth" => max_depth,
        "query_handling" => query_handling,
        "user_agent" => effective_user_agent,
        "request_rate_per_second" => request_rate_per_second.to_s("F"),
        "max_concurrency" => max_concurrency,
        "robots_behavior" => robots_behavior,
        "rendering_sample_percent" => rendering_sample_percent,
        "max_rendered_pages" => max_rendered_pages,
        "artifact_retention_days" => artifact_retention_days
      }.freeze
    end

    def effective_user_agent
      [ "SearchOpsBot/1.0", user_agent_suffix ].compact.join(" ").freeze
    end
  end
end
