# frozen_string_literal: true

module Properties
  class Environment < ApplicationRecord
    self.table_name = "property_environments"

    KINDS = %w[production staging development custom].freeze
    STATUSES = %w[active archived].freeze

    normalizes :key, with: ->(value) { value.to_s.strip.downcase }
    normalizes :display_name, with: ->(value) { value.to_s.strip }

    belongs_to :property, class_name: "Properties::Property", inverse_of: :environments

    validates :organization_id, :project_id, :property_id, presence: true
    validates :key, format: { with: /\A[a-z][a-z0-9-]{1,62}\z/ }, uniqueness: {
      scope: %i[organization_id project_id property_id], case_sensitive: false
    }
    validates :display_name, presence: true, length: { in: 2..120 }
    validates :kind, inclusion: { in: KINDS }
    validates :status, inclusion: { in: STATUSES }
    validates :property_kind, inclusion: { in: %w[website web_application] }
    validates :configuration_version, inclusion: { in: [ Property::CONFIGURATION_VERSION ] }
    validates :origin, uniqueness: { scope: %i[organization_id project_id] }
    validate :stable_identity_is_immutable, on: :update
    validate :lifecycle_is_consistent
    validate :primary_is_production_and_active
    validate :origin_is_consistent

    scope :active, -> { where(status: "active") }

    def active?
      status == "active" && archived_at.nil?
    end

    def archived?
      status == "archived" && archived_at.present?
    end

    def primary?
      self[:primary]
    end

    def origin_value
      CanonicalOrigin.new(origin: origin)
    end

    def archive!(at)
      update!(status: "archived", primary: false, archived_at: at)
    end

    def reactivate!
      update!(status: "active", primary: false, archived_at: nil)
    end

    private

    def stable_identity_is_immutable
      %i[id organization_id project_id property_id property_kind configuration_version key kind].each do |attribute|
        errors.add(attribute, "cannot be changed") if will_save_change_to_attribute?(attribute)
      end
    end

    def lifecycle_is_consistent
      errors.add(:status, "does not match archived timestamp") unless active? || archived?
    end

    def primary_is_production_and_active
      return unless primary?

      errors.add(:primary, "requires an active production environment") unless
        kind == "production" && active?
    end

    def origin_is_consistent
      value = CanonicalOrigin.new(origin: origin)
      errors.add(:origin, "does not match normalized components") unless
        value.scheme == scheme && value.host == host && value.port == port
    rescue ArgumentError => error
      errors.add(:origin, error.message)
    end
  end
end
