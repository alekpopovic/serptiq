# frozen_string_literal: true

module Crawling
  class StaticCrawlExecution < ApplicationRecord
    self.table_name = "crawl_scan_executions"

    STATES = %w[pending initializing ready completed partially_completed canceled failed].freeze
    TERMINAL_STATES = %w[completed partially_completed canceled failed].freeze
    WORKER_PATTERN = CrawlUrl::WORKER_PATTERN
    DIGEST_PATTERN = CrawlUrl::DIGEST_PATTERN

    belongs_to :scan, class_name: "Crawling::Scan"

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      presence: true
    validates :scan_id, uniqueness: true
    validates :state, inclusion: { in: STATES }
    validates :initialization_attempts,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :maximum_initialization_attempts, numericality: { only_integer: true, in: 1..10 }
    validates :initialization_worker_id, format: { with: WORKER_PATTERN }, allow_nil: true
    validates :initialization_token_digest, format: { with: DIGEST_PATTERN }, allow_nil: true
    validates :last_failure_category, format: { with: CrawlUrl::FAILURE_PATTERN }, allow_nil: true
    validate :identifier_shapes
    validate :lifecycle_shape

    STATES.each { |value| define_method("#{value}?") { state == value } }

    def terminal?
      state.in?(TERMINAL_STATES)
    end

    def initialization_token_matches?(token)
      return false unless initialization_token_digest&.match?(DIGEST_PATTERN)

      ActiveSupport::SecurityUtils.secure_compare(
        initialization_token_digest,
        Digest::SHA256.hexdigest(token.to_s)
      )
    end

    private

    def identifier_shapes
      %i[organization_id project_id property_id environment_id scan_id].each do |name|
        errors.add(name, "is invalid") unless Shared::Public.application_uuid?(public_send(name))
      end
    end

    def lifecycle_shape
      lease = [
        initialization_worker_id, initialization_token_digest,
        initialization_started_at, initialization_lease_expires_at
      ]
      valid = initializing? ? lease.none?(&:nil?) : lease.all?(&:nil?)
      valid &&= initialization_lease_expires_at > initialization_started_at if initializing?
      valid &&= initialized_at.present? if state.in?(%w[ready completed partially_completed])
      valid &&= finished_at.present? if terminal?
      errors.add(:state, "does not match initialization lifecycle") unless valid
    end
  end
end
