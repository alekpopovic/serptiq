# frozen_string_literal: true

module Tenancy
  class OrganizationOwnership < ApplicationRecord
    self.table_name = "organization_ownerships"

    belongs_to :organization, class_name: "Tenancy::Organization", inverse_of: :ownerships
    belongs_to :membership, class_name: "Tenancy::Membership", inverse_of: :ownerships

    validates :assigned_at, presence: true
    validates :organization_id, uniqueness: { conditions: -> { where(ended_at: nil) } }, if: :active?
    validate :membership_belongs_to_organization
    validate :ended_at_follows_assignment
    validate :current_ownership_cannot_end

    def active?
      ended_at.nil?
    end

    private

    def membership_belongs_to_organization
      return if membership.nil? || membership.organization_id == organization_id

      errors.add(:membership, "must belong to the organization")
    end

    def ended_at_follows_assignment
      return if ended_at.nil? || assigned_at.nil? || ended_at >= assigned_at

      errors.add(:ended_at, "must follow assignment")
    end

    def current_ownership_cannot_end
      return if ended_at.nil? || organization.nil? || organization.current_ownership_id != id

      errors.add(:ended_at, "cannot end while assigned as current ownership")
    end
  end
end
