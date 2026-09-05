# frozen_string_literal: true

module Crawling
  class CrawlLink < ApplicationRecord
    self.table_name = "crawl_links"

    CLASSIFICATIONS = %w[internal external].freeze
    SCOPE_STATUSES = %w[allowed denied].freeze
    DISCOVERY_STATUSES = %w[linked not_admitted not_applicable].freeze

    belongs_to :scan, class_name: "Crawling::Scan"
    belongs_to :page_snapshot, class_name: "Crawling::PageSnapshot", inverse_of: :crawl_links
    belongs_to :source_crawl_url, class_name: "Crawling::CrawlUrl"
    belongs_to :destination_crawl_url, class_name: "Crawling::CrawlUrl", optional: true

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :page_snapshot_id, :source_crawl_url_id, :destination_url, :destination_url_digest,
      :destination_host_digest, :classification, :scope_status, :scope_reason,
      :discovery_status, :source_locator, :anchor_digest, :edge_digest, :discovered_at,
      presence: true
    validates :destination_url_digest, :destination_host_digest, :anchor_digest, :edge_digest,
      format: { with: CrawlUrl::DIGEST_PATTERN }
    validates :destination_url, length: { maximum: 8192 }
    validates :normalization_version, numericality: { only_integer: true, in: 1..100 }
    validates :classification, inclusion: { in: CLASSIFICATIONS }
    validates :scope_status, inclusion: { in: SCOPE_STATUSES }
    validates :discovery_status, inclusion: { in: DISCOVERY_STATUSES }
    validates :scope_reason, format: { with: CrawlUrl::FAILURE_PATTERN }
    validates :source_locator, length: { in: 1..512 }
    validates :anchor_summary, length: { maximum: 512 }, allow_nil: true
    validates :occurrence_count, numericality: { only_integer: true, in: 1..5000 }
    validates :nofollow_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :identifier_shapes
    validate :rel_tokens_shape
    validate :destination_shape
    validate :nofollow_shape

    scope :internal, -> { where(classification: "internal") }
    scope :external, -> { where(classification: "external") }

    private

    def identifier_shapes
      %i[organization_id project_id property_id environment_id scan_id].each do |name|
        errors.add(name, "is invalid") unless Shared::Public.application_uuid?(public_send(name))
      end
    end

    def rel_tokens_shape
      valid = rel_tokens.is_a?(Array) && rel_tokens.length <= 20 &&
        rel_tokens == rel_tokens.uniq.sort &&
        rel_tokens.all? { |token| token.match?(/\A[a-z][a-z0-9_-]{0,63}\z/) }
      errors.add(:rel_tokens, "must be bounded normalized tokens") unless valid
    end

    def destination_shape
      valid = if classification == "external"
        scope_status == "denied" && destination_crawl_url_id.nil? &&
          discovery_status == "not_applicable"
      elsif scope_status == "allowed"
        (destination_crawl_url_id.present? && discovery_status == "linked") ||
          (destination_crawl_url_id.nil? && discovery_status == "not_admitted")
      else
        destination_crawl_url_id.nil? && discovery_status == "not_applicable"
      end
      errors.add(:destination_crawl_url_id, "does not match link scope") unless valid
    end

    def nofollow_shape
      valid = nofollow_count.to_i.between?(0, occurrence_count.to_i) &&
        nofollow == nofollow_count.positive?
      errors.add(:nofollow, "does not match occurrence evidence") unless valid
    end
  end
end
