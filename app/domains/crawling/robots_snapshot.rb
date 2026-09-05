# frozen_string_literal: true

module Crawling
  class RobotsSnapshot < ApplicationRecord
    self.table_name = "crawl_robots_snapshots"

    RETRIEVAL_STATUSES = RobotsRetrieval::STATUSES
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

    belongs_to :scan, class_name: "Crawling::Scan", inverse_of: :robots_snapshots

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :origin, :origin_digest, :source_url, :retrieval_status, :retrieved_at, presence: true
    validates :origin, :source_url, :final_url, length: { maximum: 2048 }, allow_nil: true
    validates :retrieval_status, inclusion: { in: RETRIEVAL_STATUSES }
    validates :origin_digest, :artifact_sha256, format: { with: DIGEST_PATTERN }, allow_nil: true
    validates :parser_version, numericality: { only_integer: true, greater_than: 0 }
    validates :redirect_count, numericality: { only_integer: true, in: 0..5 }
    validates :http_status, numericality: { only_integer: true, in: 100..599 }, allow_nil: true
    validates :error_code, format: { with: RobotsRetrieval::ERROR_PATTERN }, allow_nil: true
    validate :bounded_payloads

    def readonly?
      persisted?
    end

    def document
      RobotsDocument.new(
        groups: parsed_groups,
        sitemap_urls: sitemap_urls,
        warnings: parse_warnings,
        parser_version: parser_version,
        malformed: malformed
      )
    end

    private

    def parsed_groups
      Array(groups).map do |group|
        RobotsGroup.new(
          agents: group.fetch("agents"),
          rules: Array(group.fetch("rules")).map { |rule| RobotsRule.new(**rule.symbolize_keys) }
        )
      end
    end

    def parse_warnings
      Array(warnings).map { |warning| RobotsWarning.new(**warning.symbolize_keys) }
    end

    def bounded_payloads
      errors.add(:groups, "is too large") if JSON.generate(groups).bytesize > 1.megabyte
      errors.add(:warnings, "is too large") if JSON.generate(warnings).bytesize > 1.megabyte
      errors.add(:sitemap_urls, "has too many values") if
        Array(sitemap_urls).length > RobotsParser::MAXIMUM_SITEMAPS
    end
  end
end
