# frozen_string_literal: true

module Tenancy
  class InvitationRateLimitBucket < ApplicationRecord
    self.table_name = "invitation_rate_limit_buckets"

    SCOPES = %w[issue_actor issue_destination accept_ip].freeze
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

    validates :scope, inclusion: { in: SCOPES }
    validates :key_digest, format: { with: DIGEST_PATTERN }
    validates :request_count, numericality: { only_integer: true, greater_than: 0 }
    validates :window_started_at, :expires_at, presence: true
  end
end
