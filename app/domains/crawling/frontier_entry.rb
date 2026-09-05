# frozen_string_literal: true

require "digest"

module Crawling
  FRONTIER_DISCOVERY_SOURCES = %w[seed sitemap link redirect canonical].freeze

  FrontierEntry = Data.define(
    :fetch_url, :normalized_url, :normalized_url_digest, :normalization_version, :host_digest,
    :depth, :priority, :discovery_source, :discovered_from_id
  ) do
    def initialize(url:, depth:, priority: 0, discovery_source:, discovered_from_id: nil,
      normalization_version: UrlNormalizer::CURRENT_VERSION, query_handling: "all",
      query_parameter_allowlist: [], query_parameter_denylist: [],
      normalizer: UrlNormalizer.new, digestor: ->(value) { Digest::SHA256.hexdigest(value) })
      normalized = normalizer.call(
        url: url,
        normalization_version: normalization_version,
        query_handling: query_handling,
        query_parameter_allowlist: query_parameter_allowlist,
        query_parameter_denylist: query_parameter_denylist,
        digestor: digestor
      )
      normalized_depth = Integer(depth)
      normalized_priority = Integer(priority)
      source = discovery_source.to_s
      parent_id = discovered_from_id.nil? ? nil : Integer(discovered_from_id)
      valid = normalized_depth.between?(0, 100) && normalized_priority.between?(-1_000_000, 1_000_000) &&
        FRONTIER_DISCOVERY_SOURCES.include?(source) && (parent_id.nil? || parent_id.positive?)
      raise ArgumentError, "frontier entry is invalid" unless valid

      super(
        fetch_url: normalized.fetch_url,
        normalized_url: normalized.identity_url,
        normalized_url_digest: normalized.identity_digest,
        normalization_version: normalized.normalization_version,
        host_digest: normalized.host_digest,
        depth: normalized_depth,
        priority: normalized_priority,
        discovery_source: source.freeze,
        discovered_from_id: parent_id
      )
      freeze
    rescue ArgumentError
      raise
    rescue StandardError => error
      raise ArgumentError, "frontier entry is invalid", cause: error
    end
  end
end
