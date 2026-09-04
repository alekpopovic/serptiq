# frozen_string_literal: true

module Plans
  Offer = Data.define(
    :id, :plan_key, :display_order, :version, :status, :display_name, :positioning,
    :currency, :pricing_kind, :monthly_price_cents, :annual_price_cents,
    :entitlements, :effective_at, :offered, :current
  ) do
    def self.from_record(record, display_order:, offered:, current:)
      new(
        id: record.id,
        plan_key: record.plan.key,
        display_order: display_order,
        version: record.version,
        status: record.status,
        display_name: record.display_name,
        positioning: record.positioning,
        currency: record.currency,
        pricing_kind: record.pricing_kind,
        monthly_price_cents: record.monthly_price_cents,
        annual_price_cents: record.annual_price_cents,
        entitlements: record.entitlements_snapshot,
        effective_at: record.effective_at,
        offered: offered,
        current: current
      )
    end

    def initialize(**attributes)
      attributes[:entitlements] = attributes.fetch(:entitlements).to_h.each_with_object({}) do |(key, value), result|
        result[key.to_s.dup.freeze] = value.is_a?(String) ? value.dup.freeze : value
      end.freeze
      super(**attributes)
      freeze
    end

    def custom_pricing?
      pricing_kind == "custom"
    end

    def offered?
      offered
    end

    def current?
      current
    end

    def grandfathered?
      status == "grandfathered"
    end

    def price_for(interval)
      public_send("#{interval}_price_cents") if %w[monthly annual].include?(interval.to_s)
    end

    def billing_intervals
      custom_pricing? ? [] : %w[monthly annual]
    end

    def entitlement_value(key)
      entitlements[key.to_s]
    end

    def direction_from(other)
      return "current" if current?
      return "select" unless other

      comparison = display_order <=> other.display_order
      return "upgrade" if comparison.positive?
      return "downgrade" if comparison.negative?

      "migration"
    end
  end
end
