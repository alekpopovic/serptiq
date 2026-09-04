# frozen_string_literal: true

module Usage
  class ReservationLimitResolver
    ZERO = BigDecimal("0").freeze

    def call(organization_id:, meter_definition:, at:)
      key = meter_definition.quota_entitlement_key
      return unlimited_snapshot if key.nil?

      resolution = Entitlements::Public.resolve(
        organization_id: organization_id,
        entitlement_key: key,
        at: at
      )
      limit = resolution.value
      unless limit.is_a?(Integer) && limit >= 0 && %w[enabled disabled].include?(resolution.state)
        raise Invalid.new(reason_code: "usage_quota_limit_unavailable")
      end

      context = Entitlements::Public.active_subscription_context(organization_id: organization_id)
      context = nil unless context&.plan_version_id == resolution.plan_version_id
      ReservationLimitSnapshot.new(
        kind: "capped",
        limit: BigDecimal(limit.to_s),
        entitlement_key: key,
        entitlement_state: resolution.state,
        entitlement_provenance: resolution.provenance,
        entitlement_definition_checksum: resolution.definition_checksum,
        entitlement_override_id: resolution.override_id,
        subscription_id: context&.subscription_id,
        plan_version_id: resolution.plan_version_id,
        subscription_revision: context&.revision
      )
    end

    private

    def unlimited_snapshot
      ReservationLimitSnapshot.new(
        kind: "unlimited",
        limit: nil,
        entitlement_key: nil,
        entitlement_state: "unlimited",
        entitlement_provenance: "meter_definition",
        entitlement_definition_checksum: nil,
        entitlement_override_id: nil,
        subscription_id: nil,
        plan_version_id: nil,
        subscription_revision: nil
      )
    end
  end
end
