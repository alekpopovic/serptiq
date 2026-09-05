# frozen_string_literal: true

require "digest"

module Crawling
  FRONTIER_DISCOVERY_SOURCES = %w[seed sitemap link redirect canonical].freeze
  FRONTIER_MAXIMUM_URL_BYTES = 8192

  FrontierEntry = Data.define(
    :normalized_url, :normalized_url_digest, :normalization_version, :host_digest,
    :depth, :priority, :discovery_source, :discovered_from_id
  ) do
    def initialize(url:, depth:, priority: 0, discovery_source:, discovered_from_id: nil,
      normalization_version: 1, digestor: ->(value) { Digest::SHA256.hexdigest(value) })
      target = Shared::Public.http_target(url: url)
      normalized_url = target.url
      version = Integer(normalization_version)
      normalized_depth = Integer(depth)
      normalized_priority = Integer(priority)
      source = discovery_source.to_s
      parent_id = discovered_from_id.nil? ? nil : Integer(discovered_from_id)
      valid = normalized_url.bytesize.between?(1, FRONTIER_MAXIMUM_URL_BYTES) && version.positive? &&
        normalized_depth.between?(0, 100) && normalized_priority.between?(-1_000_000, 1_000_000) &&
        FRONTIER_DISCOVERY_SOURCES.include?(source) && (parent_id.nil? || parent_id.positive?)
      raise ArgumentError, "frontier entry is invalid" unless valid

      identity = digestor.call("crawl-url:v#{version}:#{normalized_url}").to_s
      host = digestor.call("crawl-host:v1:#{target.host}").to_s
      raise ArgumentError, "frontier digest is invalid" unless
        identity.match?(/\A[0-9a-f]{64}\z/) && host.match?(/\A[0-9a-f]{64}\z/)

      super(
        normalized_url: normalized_url.freeze,
        normalized_url_digest: identity.freeze,
        normalization_version: version,
        host_digest: host.freeze,
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
