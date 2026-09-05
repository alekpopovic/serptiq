# frozen_string_literal: true

module Crawling
  class ResolveAdmissionBillingPeriod
    def call(organization_id:, at: Time.current)
      subscription = Billing::Public.active_subscription(organization_id: organization_id)
      raise Invalid.new(
        field_errors: { base: "An active billing period is required." },
        reason_code: "scan_billing_period_unavailable"
      ) unless subscription

      starts_at, ends_at = period_bounds(subscription, at)
      Usage::Public::BillingPeriod.new(
        starts_at: starts_at,
        ends_at: ends_at,
        time_zone_name: "UTC",
        reference: "subscription:#{subscription.id}:#{starts_at.to_i}:#{ends_at.to_i}"
      )
    end

    private

    def period_bounds(subscription, at)
      starts_at = subscription.current_period_starts_at
      ends_at = subscription.current_period_ends_at
      if starts_at && ends_at && starts_at <= at && at < ends_at
        return [ starts_at, ends_at ]
      end
      if subscription.provider_backed?
        raise Invalid.new(
          field_errors: { base: "The provider billing period is unavailable." },
          reason_code: "scan_billing_period_unavailable"
        )
      end

      start = Time.utc(at.utc.year, at.utc.month, 1)
      [ start, start.next_month ]
    end
  end
end
