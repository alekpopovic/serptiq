# frozen_string_literal: true

module Usage
  ReservationLimitSnapshot = Data.define(
    :kind, :limit, :entitlement_key, :entitlement_state, :entitlement_provenance,
    :entitlement_definition_checksum, :entitlement_override_id,
    :subscription_id, :plan_version_id, :subscription_revision
  ) do
    def initialize(**attributes)
      %i[
        kind entitlement_key entitlement_state entitlement_provenance
        entitlement_definition_checksum entitlement_override_id subscription_id plan_version_id
      ].each do |name|
        attributes[name] = attributes[name]&.to_s&.freeze
      end
      super(**attributes)
      freeze
    end

    def unlimited?
      kind == "unlimited"
    end
  end
end
