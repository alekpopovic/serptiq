# frozen_string_literal: true

module Entitlements
  class OrganizationOverride < ApplicationRecord
    self.table_name = "organization_entitlement_overrides"

    SOURCES = %w[contract support emergency].freeze

    belongs_to :definition, class_name: "Entitlements::Definition",
      foreign_key: :entitlement_definition_id, inverse_of: :organization_overrides

    validates :organization_id, :created_by_membership_id, :starts_at, presence: true
    validates :source, inclusion: { in: SOURCES }
    validates :reason, length: { in: 3..500 }, presence: true
    validates :entitlement_definition_id, uniqueness: {
      scope: :organization_id, conditions: -> { where(revoked_at: nil) }, if: -> { revoked_at.nil? }
    }
    validate :identifier_shapes
    validate :validity_order
    validate :revocation_shape
    validate :definition_type_matches
    validate :value_is_typed

    scope :applicable_at, ->(at) {
      where(revoked_at: nil).where("starts_at <= ? AND (ends_at IS NULL OR ends_at > ?)", at, at)
    }

    def active_at?(at)
      revoked_at.nil? && starts_at <= at && (ends_at.nil? || ends_at > at)
    end

    private

    def identifier_shapes
      %i[organization_id created_by_membership_id].each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
      if revoked_by_membership_id && !Shared::Public.application_uuid?(revoked_by_membership_id)
        errors.add(:revoked_by_membership_id, "is invalid")
      end
    end

    def validity_order
      errors.add(:ends_at, "must follow the start") if ends_at && starts_at && ends_at <= starts_at
    end

    def revocation_shape
      paired = revoked_at.present? == revoked_by_membership_id.present?
      ordered = revoked_at.nil? || created_at.nil? || revoked_at >= created_at
      errors.add(:revoked_at, "does not match revocation attribution") unless paired && ordered
    end

    def definition_type_matches
      errors.add(:value_type, "does not match definition") if definition && value_type != definition.value_type
    end

    def value_is_typed
      return unless definition

      TypedValue.new.deserialize(definition: definition, state: "configured", stored_value: value)
    rescue OverrideInvalid => error
      errors.add(:value, error.reason_code)
    end
  end
end
