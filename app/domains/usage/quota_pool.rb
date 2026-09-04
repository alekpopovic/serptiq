# frozen_string_literal: true

module Usage
  class QuotaPool
    Balance = Data.define(:used, :reserved)
    ZERO = BigDecimal("0").freeze

    def lock!(window)
      connection = ActiveRecord::Base.connection
      quoted_id = connection.quote(window.id)
      connection.execute("SELECT lock_usage_quota_pool(#{quoted_id}::uuid)")
      true
    end

    def balance(window:, at:, excluding_reservation_id: nil)
      ids = window_ids(window)
      used = UsageEvent.where(
        organization_id: window.organization_id,
        usage_window_id: ids
      ).sum(:billed_quantity)
      reservations = QuotaReservation.where(
        organization_id: window.organization_id,
        usage_window_id: ids,
        state: "held"
      ).where("expires_at > ?", at)
      reservations = reservations.where.not(id: excluding_reservation_id) if excluding_reservation_id
      Balance.new(used || ZERO, reservations.sum(:held_quantity) || ZERO)
    end

    def window_ids(window)
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
        ends_at: window.ends_at
      ).pluck(:id)
    end
  end
end
