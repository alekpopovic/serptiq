# frozen_string_literal: true

module Crawling
  class RenderedLink < ApplicationRecord
    self.table_name = "crawl_rendered_links"

    belongs_to :scan, class_name: "Crawling::Scan"
    belongs_to :page_render, class_name: "Crawling::PageRender", inverse_of: :rendered_links

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :page_render_id, :destination_url, :destination_url_digest, :destination_host_digest,
      :normalization_version, :classification, :scope_status, :scope_reason,
      :source_locator, :anchor_digest, :edge_digest, presence: true
    validates :destination_url_digest, :destination_host_digest, :anchor_digest, :edge_digest,
      format: { with: CrawlUrl::DIGEST_PATTERN }
    validates :destination_url, length: { maximum: 8192 }
    validates :normalization_version, numericality: { only_integer: true, in: 1..100 }
    validates :classification, inclusion: { in: CrawlLink::CLASSIFICATIONS }
    validates :scope_status, inclusion: { in: CrawlLink::SCOPE_STATUSES }
    validates :scope_reason, format: { with: CrawlUrl::FAILURE_PATTERN }
    validates :source_locator, length: { in: 1..512 }
    validates :anchor_summary, length: { maximum: 512 }, allow_nil: true
    validates :occurrence_count, numericality: { only_integer: true, in: 1..5000 }
    validates :nofollow_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :identifier_shapes
    validate :rel_tokens_shape
    validate :nofollow_shape

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

    def nofollow_shape
      errors.add(:nofollow_count, "cannot exceed occurrences") unless
        nofollow_count.to_i.between?(0, occurrence_count.to_i)
    end
  end
end
