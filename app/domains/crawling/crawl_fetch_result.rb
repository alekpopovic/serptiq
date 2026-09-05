# frozen_string_literal: true

module Crawling
  class CrawlFetchResult < ApplicationRecord
    self.table_name = "crawl_fetch_results"

    OUTCOMES = HttpFetchResult::OUTCOMES
    METHODS = %w[GET HEAD].freeze
    DIGEST_PATTERN = CrawlUrl::DIGEST_PATTERN

    belongs_to :scan, class_name: "Crawling::Scan"
    belongs_to :crawl_url, class_name: "Crawling::CrawlUrl"
    belongs_to :artifact, class_name: "Crawling::Artifact", optional: true
    has_one :page_snapshot, class_name: "Crawling::PageSnapshot",
      foreign_key: :crawl_fetch_result_id, inverse_of: :fetch_result,
      dependent: :restrict_with_exception

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :crawl_url_id, :attempt_number, :request_method, :outcome, :final_url,
      :content_encoding, :body_sha256, :sniffed_kind, :fetched_at, presence: true
    validates :attempt_number, numericality: { only_integer: true, in: 1..10 }
    validates :source_key_digest, :lease_token_digest, :final_url_digest, :body_sha256,
      format: { with: DIGEST_PATTERN }
    validates :request_method, inclusion: { in: METHODS }
    validates :outcome, inclusion: { in: OUTCOMES }
    validates :sniffed_kind, inclusion: { in: HttpFetchResult::SNIFFED_KINDS }
    validates :failure_category, format: { with: CrawlUrl::FAILURE_PATTERN }, allow_nil: true
    validates :http_status_code, numericality: {
      only_integer: true, in: 100..599
    }, allow_nil: true
    validates :final_url, length: { maximum: 8192 }
    validates :media_type, format: { with: Artifact::MEDIA_TYPE_PATTERN }, allow_nil: true
    validates :request_count, numericality: { only_integer: true, in: 0..32 }
    validates :retry_count, numericality: { only_integer: true, in: 0..10 }
    validates :redirect_count, numericality: { only_integer: true, in: 0..20 }
    validates :duration_ms, numericality: { only_integer: true, in: 0..600_000 }
    validate :identifier_shapes
    validate :bounded_metadata
    validate :outcome_evidence

    private

    def identifier_shapes
      %i[organization_id project_id property_id environment_id scan_id].each do |name|
        errors.add(name, "is invalid") unless Shared::Public.application_uuid?(public_send(name))
      end
      errors.add(:artifact_id, "is invalid") if
        artifact_id.present? && !Shared::Public.application_uuid?(artifact_id)
    end

    def bounded_metadata
      valid = response_headers.is_a?(Hash) && JSON.generate(response_headers).bytesize <= 16.kilobytes &&
        retry_count.to_i <= request_count.to_i && redirect_count.to_i <= request_count.to_i
      errors.add(:response_headers, "must be a bounded object") unless valid
    end

    def outcome_evidence
      valid = if outcome == "succeeded"
        failure_category.nil? && http_status_code&.between?(200, 299)
      elsif outcome == "http_error"
        http_status_code.present? && !http_status_code.between?(200, 299) &&
          failure_category == "http_#{http_status_code}"
      else
        OUTCOMES.include?(outcome) && failure_category.present?
      end
      errors.add(:outcome, "does not match response evidence") unless valid
    end
  end
end
