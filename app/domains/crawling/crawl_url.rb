# frozen_string_literal: true

module Crawling
  class CrawlUrl < ApplicationRecord
    self.table_name = "crawl_urls"

    STATES = %w[pending leased succeeded rejected failed exhausted].freeze
    TERMINAL_STATES = %w[succeeded rejected failed exhausted].freeze
    DISCOVERY_SOURCES = %w[seed sitemap link redirect canonical].freeze
    LEASE_OUTCOMES = %w[retry stale_recovered succeeded rejected failed exhausted].freeze
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/
    FAILURE_PATTERN = /\A[a-z][a-z0-9_]{0,63}\z/
    WORKER_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9._:-]{0,127}\z/

    belongs_to :scan, class_name: "Crawling::Scan", inverse_of: :crawl_urls
    belongs_to :discovered_from, class_name: "Crawling::CrawlUrl", optional: true

    validates :organization_id, :project_id, :property_id, :environment_id, :scan_id,
      :fetch_url, :normalized_url, presence: true
    validates :next_attempt_at, presence: true, if: :pending?
    validates :normalized_url_digest, :host_digest, format: { with: DIGEST_PATTERN }
    validates :normalized_url_digest, uniqueness: { scope: :scan_id }
    validates :fetch_url, :normalized_url, length: { maximum: 8192 }
    validates :normalization_version, numericality: { only_integer: true, greater_than: 0 }
    validates :depth, numericality: { only_integer: true, in: 0..100 }
    validates :priority, numericality: { only_integer: true, in: -1_000_000..1_000_000 }
    validates :discovery_source, inclusion: { in: DISCOVERY_SOURCES }
    validates :state, inclusion: { in: STATES }
    validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :maximum_attempts, numericality: { only_integer: true, in: 1..10 }
    validates :leased_by, format: { with: WORKER_PATTERN }, allow_nil: true
    validates :lease_token_digest, :last_lease_token_digest,
      format: { with: DIGEST_PATTERN }, allow_nil: true
    validates :last_lease_outcome, inclusion: { in: LEASE_OUTCOMES }, allow_nil: true
    validates :last_failure_category, format: { with: FAILURE_PATTERN }, allow_nil: true
    validate :lifecycle_consistency
    validate :attempt_consistency

    STATES.each { |value| define_method("#{value}?") { state == value } }

    scope :eligible_at, ->(at) { where(state: "pending").where(next_attempt_at: ..at) }
    scope :stale_at, ->(at) { where(state: "leased").where(lease_expires_at: ..at) }

    def lease_token_matches?(token)
      secure_digest_match?(lease_token_digest, token)
    end

    def last_lease_token_matches?(token)
      secure_digest_match?(last_lease_token_digest, token)
    end

    private

    def secure_digest_match?(expected, token)
      return false unless expected&.match?(DIGEST_PATTERN)

      actual = Digest::SHA256.hexdigest(token.to_s)
      ActiveSupport::SecurityUtils.secure_compare(expected, actual)
    end

    def lifecycle_consistency
      current_lease = [ leased_by, lease_token_digest, leased_at, lease_expires_at ]
      valid = if pending?
        current_lease.all?(&:nil?) && completed_at.nil? && next_attempt_at.present?
      elsif leased?
        current_lease.none?(&:nil?) && completed_at.nil? && next_attempt_at.nil? &&
          lease_expires_at > leased_at
      elsif state.in?(TERMINAL_STATES)
        current_lease.all?(&:nil?) && completed_at.present? && next_attempt_at.nil? &&
          last_lease_outcome == state && last_lease_token_digest.present? &&
          (!succeeded? || fetch_result_id.to_i.positive?)
      else
        false
      end
      errors.add(:state, "does not match frontier lifecycle") unless valid
    end

    def attempt_consistency
      valid = attempts.to_i.between?(0, maximum_attempts.to_i) &&
        (!pending? || attempts < maximum_attempts)
      errors.add(:attempts, "does not match the attempt budget") unless valid
    end
  end
end
