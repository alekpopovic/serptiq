# frozen_string_literal: true

module Tenancy
  class Membership < ApplicationRecord
    self.table_name = "memberships"

    STATUSES = %w[active suspended left].freeze

    belongs_to :organization, class_name: "Tenancy::Organization", inverse_of: :memberships
    has_many :ownerships, class_name: "Tenancy::OrganizationOwnership", inverse_of: :membership,
      dependent: :restrict_with_exception

    validates :user_id, presence: true, uniqueness: { scope: :organization_id }
    validates :status, inclusion: { in: STATUSES }
    validates :joined_at, presence: true
    validate :user_exists
    validate :lifecycle_timestamps_are_consistent

    def active?
      status == "active"
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
      when "active" then suspended_at.nil? && left_at.nil?
      when "suspended" then suspended_at.present? && left_at.nil?
      when "left" then left_at.present?
      else false
      end
      errors.add(:status, "does not match lifecycle timestamps") unless valid
    end
  end
end
