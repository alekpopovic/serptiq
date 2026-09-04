# frozen_string_literal: true

module Billing
  class SupportAccessGrant < ApplicationRecord
    self.table_name = "billing_support_access_grants"

    PERMISSIONS = %w[billing_support.read billing_support.manage].freeze

    belongs_to :user, class_name: "Identity::User"

    validates :user_id, :granted_at, presence: true
    validates :permission, inclusion: { in: PERMISSIONS }, uniqueness: {
      scope: :user_id, conditions: -> { where(revoked_at: nil) }
    }
    validate :revocation_follows_grant

    scope :active, -> { where(revoked_at: nil) }

    private

    def revocation_follows_grant
      return if revoked_at.nil? || granted_at.nil? || revoked_at >= granted_at

      errors.add(:revoked_at, "must not precede the grant")
    end
  end
end
