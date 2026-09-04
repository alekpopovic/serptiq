# frozen_string_literal: true

module Properties
  class Property < ApplicationRecord
    self.table_name = "properties"

    KINDS = %w[website web_application android_app ios_app].freeze
    STATUSES = %w[active archived].freeze
    VERIFICATION_STATUSES = %w[unverified pending verified failed expired revoked].freeze
    CONFIGURATION_VERSION = 1

    normalizes :display_name, with: ->(value) { value.to_s.strip }

    has_one :website_property_config, class_name: "Properties::WebsitePropertyConfig",
      inverse_of: :property, dependent: :restrict_with_exception
    has_one :android_property_config, class_name: "Properties::AndroidPropertyConfig",
      inverse_of: :property, dependent: :restrict_with_exception
    has_one :ios_property_config, class_name: "Properties::IosPropertyConfig",
      inverse_of: :property, dependent: :restrict_with_exception
    has_many :environments, class_name: "Properties::Environment",
      inverse_of: :property, dependent: :restrict_with_exception

    validates :organization_id, :project_id, presence: true
    validates :display_name, presence: true, length: { in: 2..160 }, uniqueness: {
      scope: %i[organization_id project_id], case_sensitive: false
    }
    validates :kind, inclusion: { in: KINDS }
    validates :status, inclusion: { in: STATUSES }
    validates :verification_status, inclusion: { in: VERIFICATION_STATUSES }
    validates :configuration_version, inclusion: { in: [ CONFIGURATION_VERSION ] }
    validates :authorization_scope_type, inclusion: { in: [ "Property" ] }
    validates :authorization_project_scope_type, inclusion: { in: [ "Project" ] }
    validate :identifier_shapes
    validate :stable_identity_is_immutable, on: :update
    validate :lifecycle_is_consistent
    validate :verification_is_consistent

    scope :active, -> { where(status: "active") }
    scope :website_family, -> { where(kind: %w[website web_application]) }
    scope :mobile_family, -> { where(kind: %w[android_app ios_app]) }

    def active?
      status == "active" && archived_at.nil?
    end

    def archived?
      status == "archived" && archived_at.present?
    end

    def verified?
      verification_status == "verified" && verified_at.present?
    end

    def scan_available?
      active? && verified?
    end

    def configuration_record
      case kind
      when "website", "web_application" then website_property_config
      when "android_app" then android_property_config
      when "ios_app" then ios_property_config
      end
    end

    private

    def identifier_shapes
      %i[organization_id project_id].each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
    end

    def stable_identity_is_immutable
      %i[id organization_id project_id kind configuration_version authorization_scope_type
        authorization_project_scope_type].each do |attribute|
        errors.add(attribute, "cannot be changed") if will_save_change_to_attribute?(attribute)
      end
    end

    def lifecycle_is_consistent
      errors.add(:status, "does not match archived timestamp") unless active? || archived?
    end

    def verification_is_consistent
      return unless verification_status == "verified" && verified_at.blank?

      errors.add(:verified_at, "is required for a verified property")
    end
  end
end
