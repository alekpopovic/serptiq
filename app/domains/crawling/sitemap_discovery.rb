# frozen_string_literal: true

module Crawling
  class SitemapDiscovery < ApplicationRecord
    self.table_name = "crawl_sitemap_discoveries"

    STATUSES = %w[running completed partially_completed failed].freeze
    COUNTERS = %i[
      documents_discovered_count documents_processed_count documents_succeeded_count
      documents_failed_count entries_observed_count entries_in_scope_count
      entries_out_of_scope_count entries_invalid_count frontier_inserted_count
      fetch_attempt_count metered_fetch_count compressed_bytes_count
      decompressed_bytes_count warning_count
    ].freeze

    belongs_to :scan, class_name: "Crawling::Scan", inverse_of: :sitemap_discovery
    has_many :sitemap_files, class_name: "Crawling::SitemapFile", inverse_of: :discovery,
      foreign_key: :sitemap_discovery_id, dependent: :restrict_with_exception

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :started_at, presence: true
    validates :scan_id, uniqueness: true
    validates :status, inclusion: { in: STATUSES }
    validates(*COUNTERS, numericality: { only_integer: true, greater_than_or_equal_to: 0 })
    validate :counter_consistency
    validate :warning_payload

    def readonly?
      persisted? && status_in_database != "running"
    end

    def terminal?
      status != "running"
    end

    private

    def counter_consistency
      errors.add(:documents_processed_count, "is inconsistent") unless
        documents_processed_count == documents_succeeded_count + documents_failed_count
      errors.add(:entries_observed_count, "is inconsistent") unless
        entries_observed_count == entries_in_scope_count + entries_out_of_scope_count + entries_invalid_count
      errors.add(:metered_fetch_count, "cannot exceed attempts") if metered_fetch_count > fetch_attempt_count
      errors.add(:frontier_inserted_count, "cannot exceed in-scope entries") if
        frontier_inserted_count > entries_in_scope_count
    end

    def warning_payload
      values = Array(warning_codes)
      errors.add(:warning_codes, "is too large") if
        values.length > 1000 || values.sum { |value| value.to_s.bytesize } > 64_000
      errors.add(:warning_codes, "is invalid") unless
        values.all? { |value| SitemapWarning::CODE_PATTERN.match?(value.to_s) }
    end
  end
end
