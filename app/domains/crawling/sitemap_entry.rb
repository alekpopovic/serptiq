# frozen_string_literal: true

module Crawling
  class SitemapEntry < ApplicationRecord
    self.table_name = "crawl_sitemap_entries"

    ENTRY_KINDS = %w[page sitemap].freeze
    SCOPE_STATUSES = %w[in_scope out_of_scope].freeze
    RELATIONSHIP_STATUSES = %w[
      frontier_inserted frontier_duplicate frontier_limit queued duplicate circular
      depth_rejected document_limit out_of_scope
    ].freeze

    belongs_to :scan, class_name: "Crawling::Scan", inverse_of: :sitemap_entries
    belongs_to :sitemap_file, class_name: "Crawling::SitemapFile", inverse_of: :entries
    belongs_to :crawl_url, class_name: "Crawling::CrawlUrl", optional: true
    belongs_to :child_sitemap_file, class_name: "Crawling::SitemapFile", optional: true

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :sitemap_file_id, :entry_kind, :location_url, :location_digest,
      :scope_status, :scope_reason, :relationship_status, presence: true
    validates :entry_kind, inclusion: { in: ENTRY_KINDS }
    validates :scope_status, inclusion: { in: SCOPE_STATUSES }
    validates :relationship_status, inclusion: { in: RELATIONSHIP_STATUSES }
    validates :location_url, length: { maximum: 8192 }
    validates :location_digest, format: { with: SitemapFile::DIGEST_PATTERN }
    validates :entry_index, :normalization_version,
      numericality: { only_integer: true, greater_than: 0 }
    validates :scope_reason, format: { with: SitemapWarning::CODE_PATTERN }
    validates :lastmod_text, length: { maximum: 64 }, allow_nil: true
    validates :lastmod_precision, inclusion: { in: %w[date datetime invalid] }, allow_nil: true

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "sitemap entries are immutable"
    end
  end
end
