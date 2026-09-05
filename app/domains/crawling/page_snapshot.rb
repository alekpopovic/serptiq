# frozen_string_literal: true

module Crawling
  class PageSnapshot < ApplicationRecord
    self.table_name = "crawl_page_snapshots"

    STATES = %w[pending processing completed failed skipped].freeze
    TERMINAL_STATES = %w[completed failed skipped].freeze

    belongs_to :scan, class_name: "Crawling::Scan"
    belongs_to :crawl_url, class_name: "Crawling::CrawlUrl"
    belongs_to :fetch_result, class_name: "Crawling::CrawlFetchResult",
      foreign_key: :crawl_fetch_result_id, inverse_of: :page_snapshot
    belongs_to :artifact, class_name: "Crawling::Artifact"

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :crawl_url_id, :crawl_fetch_result_id, :artifact_id, presence: true
    validates :state, inclusion: { in: STATES }
    validates :extraction_attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :maximum_extraction_attempts, numericality: { only_integer: true, in: 1..10 }
    validates :extraction_worker_id, format: { with: CrawlUrl::WORKER_PATTERN }, allow_nil: true
    validates :extraction_token_digest, format: { with: CrawlUrl::DIGEST_PATTERN }, allow_nil: true
    validates :last_failure_category, format: { with: CrawlUrl::FAILURE_PATTERN }, allow_nil: true
    validates :discovered_links_count, numericality: { only_integer: true, in: 0..100_000 }
    validates :discovery_parser_version, format: { with: Scan::VERSION_PATTERN }, allow_nil: true
    validate :identifier_shapes
    validate :lifecycle_shape

    STATES.each { |value| define_method("#{value}?") { state == value } }

    def terminal?
      state.in?(TERMINAL_STATES)
    end

    def extraction_token_matches?(token)
      return false unless extraction_token_digest&.match?(CrawlUrl::DIGEST_PATTERN)

      ActiveSupport::SecurityUtils.secure_compare(
        extraction_token_digest,
        Digest::SHA256.hexdigest(token.to_s)
      )
    end

    private

    def identifier_shapes
      %i[organization_id project_id property_id environment_id scan_id artifact_id].each do |name|
        errors.add(name, "is invalid") unless Shared::Public.application_uuid?(public_send(name))
      end
    end

    def lifecycle_shape
      lease = [
        extraction_worker_id, extraction_token_digest,
        extraction_started_at, extraction_lease_expires_at
      ]
      valid = if pending?
        lease.all?(&:nil?) && next_attempt_at.present? && finished_at.nil?
      elsif processing?
        lease.none?(&:nil?) && next_attempt_at.nil? && finished_at.nil? &&
          extraction_lease_expires_at > extraction_started_at
      else
        terminal? && lease.all?(&:nil?) && next_attempt_at.nil? && finished_at.present?
      end
      errors.add(:state, "does not match extraction lifecycle") unless valid
    end
  end
end
