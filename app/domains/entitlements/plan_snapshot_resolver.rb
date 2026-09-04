# frozen_string_literal: true

module Entitlements
  class PlanSnapshotResolver
    def initialize(typed_value: TypedValue.new)
      @typed_value = typed_value
    end

    def call(plan_version_id:, entitlement_key:)
      definition = Definition.find_by(key: entitlement_key.to_s)
      return nil unless definition && Shared::Public.application_uuid?(plan_version_id)

      plan_value = PlanValue.find_by(
        plan_version_id: plan_version_id,
        entitlement_definition_id: definition.id
      )
      return nil unless plan_value

      @typed_value.deserialize(
        definition: definition,
        state: plan_value.value_state,
        stored_value: plan_value.value
      )
    rescue OverrideInvalid
      nil
    end
  end
end
