# frozen_string_literal: true

module Identity
  class AuthenticationRateLimitBucket < ApplicationRecord
    self.table_name = "authentication_rate_limit_buckets"

    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

    validates :scope, inclusion: { in: AuthenticationRateLimitPolicy::SCOPES }
    validates :key_digest, presence: true, format: { with: DIGEST_PATTERN }
    validates :window_started_at, :expires_at, presence: true
    validates :request_count, numericality: { only_integer: true, greater_than: 0 }
    validate :expiry_follows_window

    private

    def expiry_follows_window
      return if expires_at.blank? || window_started_at.blank? || expires_at > window_started_at

      errors.add(:expires_at, "must follow the window start")
    end
  end
end
