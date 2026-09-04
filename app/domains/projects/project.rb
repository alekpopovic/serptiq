# frozen_string_literal: true

module Projects
  class Project < ApplicationRecord
    self.table_name = "projects"

    STATUSES = %w[active archived pending_deletion].freeze
    SLUG_PATTERN = /\A[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])\z/
    RELEASE_KEY_PATTERN = /\Aprj_[0-9a-f]{32}\z/

    normalizes :name, with: ->(value) { value.to_s.strip }
    normalizes :description, with: ->(value) { value.to_s.strip }
    normalizes :slug, with: ->(value) { ProjectSlug.call(value) }

    validates :organization_id, presence: true
    validates :name, presence: true, length: { in: 2..160 }
    validates :description, length: { maximum: 2000 }
    validates :slug, presence: true, format: { with: SLUG_PATTERN }, uniqueness: {
      scope: :organization_id, case_sensitive: false
    }
    validates :status, inclusion: { in: STATUSES }
    validates :default_locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } }
    validates :time_zone, inclusion: { in: ->(_) { ActiveSupport::TimeZone.all.map(&:name) } }
    validates :external_release_key, format: { with: RELEASE_KEY_PATTERN }, uniqueness: true
    validates :authorization_scope_type, inclusion: { in: [ "Project" ] }
    validate :identifier_shapes
    validate :stable_identity_is_immutable, on: :update
    validate :lifecycle_is_consistent

    scope :active, -> { where(status: "active") }

    def to_param
      slug
    end

    def active?
      status == "active" && archived_at.nil? && deletion_requested_at.nil?
    end

    def archived?
      status == "archived" && archived_at.present? && deletion_requested_at.nil?
    end

    def pending_deletion?
      status == "pending_deletion" && archived_at.present? && deletion_requested_at.present?
    end

    def scan_available?
      active?
    end

    private

    def identifier_shapes
      errors.add(:organization_id, "is invalid") unless Shared::Public.application_uuid?(organization_id)
    end

    def stable_identity_is_immutable
      %i[organization_id slug external_release_key authorization_scope_type].each do |attribute|
        errors.add(attribute, "cannot be changed") if will_save_change_to_attribute?(attribute)
      end
    end

    def lifecycle_is_consistent
      valid = active? || archived? || pending_deletion?
      valid &&= deletion_requested_at >= archived_at if pending_deletion?
      errors.add(:status, "does not match lifecycle timestamps") unless valid
    end
  end
end
