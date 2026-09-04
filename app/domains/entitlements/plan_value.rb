# frozen_string_literal: true

module Entitlements
  class PlanValue < ApplicationRecord
    self.table_name = "plan_entitlements"

    STATES = %w[configured custom].freeze
    CHECKSUM_PATTERN = /\A[0-9a-f]{64}\z/

    belongs_to :definition, class_name: "Entitlements::Definition",
      foreign_key: :entitlement_definition_id, inverse_of: :plan_values

    validates :plan_version_id, presence: true
    validates :value_type, inclusion: { in: Definition::TYPES }
    validates :value_state, inclusion: { in: STATES }
    validates :catalog_checksum, format: { with: CHECKSUM_PATTERN }
    validates :entitlement_definition_id, uniqueness: { scope: :plan_version_id }
    validate :definition_type_matches
    validate :value_is_typed

    private

    def definition_type_matches
      errors.add(:value_type, "does not match definition") if definition && value_type != definition.value_type
    end

    def value_is_typed
      return unless definition && STATES.include?(value_state)

      TypedValue.new.deserialize(definition: definition, state: value_state, stored_value: value)
    rescue OverrideInvalid => error
      errors.add(:value, error.reason_code)
    end
  end
end
