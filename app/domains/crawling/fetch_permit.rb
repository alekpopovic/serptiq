# frozen_string_literal: true

require "digest"

module Crawling
  class FetchPermit < ApplicationRecord
    self.table_name = "crawl_fetch_permits"

    STATES = %w[active released expired].freeze
    OUTCOMES = %w[succeeded http_error failed canceled expired].freeze
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

    belongs_to :scan, class_name: "Crawling::Scan"
    belongs_to :crawl_url, class_name: "Crawling::CrawlUrl"

    validates :organization_id, :project_id, :property_id, :environment_id,
      :scan_id, :crawl_url_id, :worker_id, :acquired_at, :expires_at, presence: true
    validates :host_key_digest, :permit_token_digest, format: { with: DIGEST_PATTERN }
    validates :worker_id, format: { with: CrawlUrl::WORKER_PATTERN }
    validates :state, inclusion: { in: STATES }
    validates :release_outcome, inclusion: { in: OUTCOMES }, allow_nil: true
    validates :failure_category, format: { with: CrawlUrl::FAILURE_PATTERN }, allow_nil: true
    validates :http_status_code, numericality: {
      only_integer: true, in: 100..599
    }, allow_nil: true
    validate :lifecycle_shape

    scope :active_at, ->(at) { where(state: "active").where("expires_at > ?", at) }
    scope :stale_at, ->(at) { where(state: "active", expires_at: ..at) }

    def token_matches?(token)
      candidate = Digest::SHA256.hexdigest(token.to_s)
      ActiveSupport::SecurityUtils.secure_compare(permit_token_digest, candidate)
    end

    private

    def lifecycle_shape
      valid = expires_at.present? && acquired_at.present? && expires_at > acquired_at
      valid &&= if state == "active"
        released_at.nil? && release_outcome.nil? && failure_category.nil? && http_status_code.nil?
      else
        released_at.present? && released_at >= acquired_at && release_outcome.in?(OUTCOMES)
      end
      valid &&= release_outcome == "expired" && failure_category == "permit_expired" if state == "expired"
      errors.add(:state, "does not match fetch permit lifecycle") unless valid
    end
  end
end
