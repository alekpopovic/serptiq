# frozen_string_literal: true

module Crawling
  class PageFact < ApplicationRecord
    self.table_name = "crawl_page_facts"

    PARSE_STATUSES = %w[parsed malformed unavailable].freeze
    FACT_STATUSES = %w[present absent malformed unavailable].freeze
    FACT_KEYS = %w[
      base title description language meta_directives headings canonical hreflang images structured_data
    ].freeze
    JSON_LIMITS = {
      fact_statuses: 4.kilobytes,
      meta_directives: 64.kilobytes,
      headings: 128.kilobytes,
      canonicals: 32.kilobytes,
      hreflangs: 64.kilobytes,
      images: 256.kilobytes,
      structured_data_blocks: 256.kilobytes,
      counts: 4.kilobytes
    }.freeze

    belongs_to :scan, class_name: "Crawling::Scan"
    belongs_to :page_snapshot, class_name: "Crawling::PageSnapshot", inverse_of: :page_fact

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :page_snapshot_id, :parser_version, :content_sha256, :fact_digest, :parse_status,
      :title_status, :description_status, :language_status, presence: true
    validates :parser_version, format: { with: Scan::VERSION_PATTERN }
    validates :content_sha256, :fact_digest, format: { with: CrawlUrl::DIGEST_PATTERN }
    validates :title_digest, :description_digest,
      format: { with: CrawlUrl::DIGEST_PATTERN }, allow_nil: true
    validates :parse_status, inclusion: { in: PARSE_STATUSES }
    validates :title_status, :description_status, :language_status,
      inclusion: { in: FACT_STATUSES }
    validates :parse_error_count, numericality: { only_integer: true, in: 0..20 }
    validates :element_count, numericality: { only_integer: true, in: 0..50_000 }
    validates :effective_base_url, length: { maximum: 8192 }, allow_nil: true
    validates :title_summary, length: { maximum: 512 }, allow_nil: true
    validates :description_summary, length: { maximum: 1024 }, allow_nil: true
    validates :document_language, length: { maximum: 64 }, allow_nil: true
    validate :identifier_shapes
    validate :fact_status_shape
    validate :bounded_json

    private

    def identifier_shapes
      %i[organization_id project_id property_id environment_id scan_id].each do |name|
        errors.add(name, "is invalid") unless Shared::Public.application_uuid?(public_send(name))
      end
    end

    def fact_status_shape
      statuses = fact_statuses.to_h.stringify_keys
      valid = statuses.keys.sort == FACT_KEYS.sort &&
        statuses.values.all? { |value| FACT_STATUSES.include?(value) }
      valid &&= [ title_status, description_status, language_status ] ==
        statuses.values_at("title", "description", "language")
      valid &&= statuses.values.all? { |value| value == "unavailable" } if parse_status == "unavailable"
      errors.add(:fact_statuses, "must describe every bounded fact") unless valid
    end

    def bounded_json
      total = 0
      JSON_LIMITS.each do |name, limit|
        value = public_send(name)
        expected = name.in?(%i[fact_statuses counts]) ? Hash : Array
        size = JSON.generate(value).bytesize rescue limit + 1
        errors.add(name, "must be bounded #{expected.name.downcase}") unless
          value.is_a?(expected) && size <= limit
        total += size
      end
      errors.add(:base, "fact payload is too large") if total > 768.kilobytes
    end
  end
end
