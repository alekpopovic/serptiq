# frozen_string_literal: true

module Plans
  class CatalogAccessGrant < ApplicationRecord
    self.table_name = "plan_catalog_access_grants"

    PERMISSIONS = %w[plan_catalog.read plan_catalog.publish].freeze

    validates :user_id, :granted_at, presence: true
    validates :permission, inclusion: { in: PERMISSIONS },
      uniqueness: { scope: :user_id, conditions: -> { where(revoked_at: nil) } }
    validate :revocation_follows_grant

    scope :active, -> { where(revoked_at: nil) }

    private

    def revocation_follows_grant
      return if revoked_at.nil? || granted_at.nil? || revoked_at >= granted_at

      errors.add(:revoked_at, "must not precede the grant")
    end
  end
end
