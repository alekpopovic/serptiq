# frozen_string_literal: true

module Tenancy
  class TeamMembership < ApplicationRecord
    self.table_name = "team_memberships"

    belongs_to :organization, class_name: "Tenancy::Organization", inverse_of: :team_memberships
    belongs_to :team, class_name: "Tenancy::Team", inverse_of: :team_memberships
    belongs_to :membership, class_name: "Tenancy::Membership", inverse_of: :team_memberships
    belongs_to :added_by_membership, class_name: "Tenancy::Membership",
      inverse_of: :team_membership_additions

    validates :added_at, presence: true
    validates :membership_id, uniqueness: { scope: :team_id, conditions: -> { where(removed_at: nil) } },
      if: :active?
    validate :all_records_share_organization
    validate :removal_follows_addition

    def active?
      removed_at.nil?
    end

    def effective?
      active? && team.active? && membership.active?
    end

    private

    def all_records_share_organization
      records = [ team, membership, added_by_membership ].compact
      return if records.all? { |record| record.organization_id == organization_id }

      errors.add(:organization_id, "must match team member and actor")
    end

    def removal_follows_addition
      return if removed_at.nil? || added_at.nil? || removed_at >= added_at

      errors.add(:removed_at, "must follow addition")
    end
  end
end
