# frozen_string_literal: true

module Crawling
  class ControlAccessGrant < ApplicationRecord
    self.table_name = "crawl_control_access_grants"

    PERMISSION = "crawler_control.manage"

    belongs_to :user, class_name: "Identity::User"

    validates :user_id, :granted_at, presence: true
    validates :permission, inclusion: { in: [ PERMISSION ] }, uniqueness: {
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
