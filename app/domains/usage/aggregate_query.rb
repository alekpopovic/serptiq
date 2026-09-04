# frozen_string_literal: true

module Usage
  class AggregateQuery
    ZERO = BigDecimal("0").freeze

    def initialize(quantity: Quantity.new)
      @quantity = quantity
    end

    def call(organization_id:, window_id:, reserved: ZERO)
      window = UsageWindow.includes(:meter_definition).find_by(
        id: window_id, organization_id: organization_id
      )
      raise Invalid.new(reason_code: "usage_window_not_found") unless window

      reserved_quantity = normalize_reserved(reserved)
      used = UsageEvent.where(
        organization_id: organization_id,
        usage_window_id: pooled_window_ids(window)
      ).sum(:billed_quantity)
      limit, unlimited = resolve_limit(window)
      remaining = unlimited ? nil : [ limit - used - reserved_quantity, ZERO ].max
      UsageSummary.new(
        organization_id: organization_id,
        window_id: window.id,
        meter_key: window.meter_definition.key,
        pool_key: window.meter_definition.pool_key,
        unit: window.meter_definition.billing_unit,
        used: used,
        reserved: reserved_quantity,
        limit: limit,
        remaining: remaining,
        unlimited: unlimited,
        starts_at: window.starts_at,
        ends_at: window.ends_at
      )
    end

    private

    def normalize_reserved(raw)
      return ZERO if raw == ZERO || raw == 0

      value = @quantity.call(raw)
      raise Invalid.new(reason_code: "usage_reserved_invalid") if value.negative?

      value
    end

    def pooled_window_ids(window)
      definition = window.meter_definition
      meter_ids = MeterDefinition.where(
        pool_key: definition.pool_key,
        billing_unit: definition.billing_unit,
        quota_entitlement_key: definition.quota_entitlement_key,
        window_policy: definition.window_policy
      ).pluck(:id)
      UsageWindow.where(
        organization_id: window.organization_id,
        usage_meter_definition_id: meter_ids,
        starts_at: window.starts_at,
        ends_at: window.ends_at,
        period_reference_digest: window.period_reference_digest,
        subscription_id: window.subscription_id,
        plan_version_id: window.plan_version_id
      ).pluck(:id)
    end

    def resolve_limit(window)
      key = window.meter_definition.quota_entitlement_key
      return [ nil, true ] if key.nil?

      normalized = Entitlements::Public.resolve_plan_snapshot(
        plan_version_id: window.plan_version_id,
        entitlement_key: key
      )
      value = normalized&.value
      return [ BigDecimal(value.to_s), false ] if value.is_a?(Integer) && value >= 0

      [ ZERO, false ]
    end
  end
end
