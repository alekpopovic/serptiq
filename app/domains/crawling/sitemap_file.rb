# frozen_string_literal: true

module Crawling
  class SitemapFile < ApplicationRecord
    self.table_name = "crawl_sitemap_files"

    STATUSES = %w[pending fetched unavailable unreachable oversized malformed rejected].freeze
    SOURCES = %w[configured robots well_known sitemap_index].freeze
    DOCUMENT_KINDS = %w[urlset sitemap_index].freeze
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

    belongs_to :scan, class_name: "Crawling::Scan", inverse_of: :sitemap_files
    belongs_to :discovery, class_name: "Crawling::SitemapDiscovery",
      foreign_key: :sitemap_discovery_id, inverse_of: :sitemap_files
    belongs_to :parent, class_name: "Crawling::SitemapFile",
      foreign_key: :parent_sitemap_file_id, optional: true
    has_many :children, class_name: "Crawling::SitemapFile",
      foreign_key: :parent_sitemap_file_id, inverse_of: :parent, dependent: :restrict_with_exception
    has_many :entries, class_name: "Crawling::SitemapEntry",
      foreign_key: :sitemap_file_id, inverse_of: :sitemap_file, dependent: :restrict_with_exception

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :sitemap_discovery_id, :url, :url_digest, :source, :status, presence: true
    validates :url, :final_url, length: { maximum: 8192 }, allow_nil: true
    validates :url_digest, :artifact_sha256, format: { with: DIGEST_PATTERN }, allow_nil: true
    validates :source, inclusion: { in: SOURCES }
    validates :status, inclusion: { in: STATUSES }
    validates :document_kind, inclusion: { in: DOCUMENT_KINDS }, allow_nil: true
    validates :index_depth, numericality: { only_integer: true, in: 0..10 }
    validates :http_status, numericality: { only_integer: true, in: 100..599 }, allow_nil: true
    validates :redirect_count, numericality: { only_integer: true, in: 0..5 }, allow_nil: true
    validates :entry_count, :entries_in_scope_count, :entries_out_of_scope_count,
      :entries_invalid_count, :child_count,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :warning_count, numericality: { only_integer: true, in: 0..1000 }
    validates :error_code, format: { with: SitemapWarning::CODE_PATTERN }, allow_nil: true
    validate :warning_payload
    validate :entry_counter_consistency

    def readonly?
      persisted? && status_in_database != "pending"
    end

    private

    def warning_payload
      valid = warnings.is_a?(Array) && JSON.generate(warnings).bytesize <= 128.kilobytes
      errors.add(:warnings, "must be a bounded array") unless valid
    end

    def entry_counter_consistency
      errors.add(:entry_count, "is inconsistent") unless
        entry_count == entries_in_scope_count + entries_out_of_scope_count + entries_invalid_count
    end
  end
end
