# frozen_string_literal: true

module Plans
  PlanVersionSummary = Data.define(
    :id, :plan_key, :version, :status, :display_name, :positioning, :currency,
    :pricing_kind, :monthly_price_cents, :annual_price_cents, :effective_at
  ) do
    def initialize(**attributes)
      super(**attributes)
      freeze
    end

    def custom_pricing?
      pricing_kind == "custom"
    end
  end
end
