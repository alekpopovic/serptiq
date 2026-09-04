# frozen_string_literal: true

module Tenancy
  class Organization < ApplicationRecord
    self.table_name = "organizations"

    STATUSES = %w[active suspended pending_deletion deleted].freeze
    SLUG_PATTERN = /\A[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])\z/
    DATA_REGION_PATTERN = /\A[a-z][a-z0-9_-]{1,31}\z/

    has_many :memberships, class_name: "Tenancy::Membership", inverse_of: :organization,
      dependent: :restrict_with_exception
    has_many :ownerships, class_name: "Tenancy::OrganizationOwnership", inverse_of: :organization,
      dependent: :restrict_with_exception
    belongs_to :current_ownership,
      class_name: "Tenancy::OrganizationOwnership",
      optional: true

    normalizes :name, with: ->(value) { value.to_s.strip }
    normalizes :slug, with: ->(value) { OrganizationSlug.call(value) }

    validates :name, presence: true, length: { in: 2..160 }
    validates :current_ownership_id, presence: true
    validates :slug, presence: true, format: { with: SLUG_PATTERN }, uniqueness: {
      case_sensitive: false,
      conditions: -> { where(deleted_at: nil) }
    }
    validates :status, inclusion: { in: STATUSES }
    validates :default_locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }
    validates :time_zone, inclusion: { in: ->(_) { ActiveSupport::TimeZone.all.map(&:name) } }
    validates :data_region, format: { with: DATA_REGION_PATTERN }
    validate :lifecycle_timestamps_are_consistent

    def active?
      status == "active" && deleted_at.nil?
    end

    private

    def lifecycle_timestamps_are_consistent
      valid = case status
      when "active"
        suspended_at.nil? && deletion_requested_at.nil? && deleted_at.nil?
      when "suspended"
        suspended_at.present? && deletion_requested_at.nil? && deleted_at.nil?
      when "pending_deletion"
        deletion_requested_at.present? && deleted_at.nil?
      when "deleted"
        deletion_requested_at.present? && deleted_at.present? && deleted_at >= deletion_requested_at
      else
        false
      end
      errors.add(:status, "does not match lifecycle timestamps") unless valid
    end
  end
end
