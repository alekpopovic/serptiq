# frozen_string_literal: true

module Tenancy
  class Team < ApplicationRecord
    self.table_name = "teams"

    STATUSES = %w[active archived].freeze

    belongs_to :organization, class_name: "Tenancy::Organization", inverse_of: :teams
    has_many :team_memberships, class_name: "Tenancy::TeamMembership", inverse_of: :team,
      dependent: :restrict_with_exception

    normalizes :name, with: ->(value) { value.to_s.strip }

    validates :name, presence: true, length: { in: 2..120 }, uniqueness: {
      scope: :organization_id,
      case_sensitive: false,
      conditions: -> { where(archived_at: nil) }
    }
    validates :status, inclusion: { in: STATUSES }
    validate :lifecycle_is_consistent

    def active?
      status == "active" && archived_at.nil?
    end

    def archived?
      status == "archived" && archived_at.present?
    end

    private

    def lifecycle_is_consistent
      valid = active? || archived?
      errors.add(:status, "does not match archive timestamp") unless valid
    end
  end
end
