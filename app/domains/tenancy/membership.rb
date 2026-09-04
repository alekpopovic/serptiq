# frozen_string_literal: true

module Tenancy
  class Membership < ApplicationRecord
    self.table_name = "memberships"

    STATUSES = %w[invited active suspended removed].freeze

    belongs_to :organization, class_name: "Tenancy::Organization", inverse_of: :memberships
    has_many :ownerships, class_name: "Tenancy::OrganizationOwnership", inverse_of: :membership,
      dependent: :restrict_with_exception
    has_many :team_memberships, class_name: "Tenancy::TeamMembership", inverse_of: :membership,
      dependent: :restrict_with_exception
    has_many :team_membership_additions, class_name: "Tenancy::TeamMembership",
      foreign_key: :added_by_membership_id, inverse_of: :added_by_membership,
      dependent: :restrict_with_exception

    validates :user_id, presence: true, uniqueness: { scope: :organization_id }
    validates :status, inclusion: { in: STATUSES }
    normalizes :display_name, with: ->(value) { value.to_s.strip }

    validates :display_name, presence: true, length: { maximum: 160 }
    validate :user_exists
    validate :lifecycle_timestamps_are_consistent
    validate :current_owner_remains_active

    def active?
      status == "active"
    end

    def invited?
      status == "invited"
    end

    def suspended?
      status == "suspended"
    end

    def removed?
      status == "removed"
    end

    def user
      Identity::Public.find_user!(id: user_id)
    end

    def owner?
      ownerships.where(ended_at: nil).exists?
    end

    private

    def user_exists
      Identity::Public.find_user!(id: user_id)
    rescue ActiveRecord::RecordNotFound
      errors.add(:user_id, "must reference a user")
    end

    def lifecycle_timestamps_are_consistent
      valid = case status
      when "invited" then accepted_at.nil? && suspended_at.nil? && removed_at.nil?
      when "active" then accepted_at.present? && suspended_at.nil? && removed_at.nil?
      when "suspended" then accepted_at.present? && suspended_at.present? && removed_at.nil?
      when "removed" then suspended_at.nil? && removed_at.present?
      else false
      end
      errors.add(:status, "does not match lifecycle timestamps") unless valid
    end

    def current_owner_remains_active
      return if active? || id.nil? || organization.nil?
      return unless organization.current_ownership&.membership_id == id

      errors.add(:status, "cannot deactivate the current owner")
    end
  end
end
