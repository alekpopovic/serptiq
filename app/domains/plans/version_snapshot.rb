# frozen_string_literal: true

module Plans
  VersionSnapshot = Data.define(
    :id, :plan_key, :version, :status, :display_name, :currency, :pricing_kind,
    :monthly_price_cents, :annual_price_cents
  ) do
    def initialize(**attributes)
      super(**attributes)
      freeze
    end

    def price_for(interval)
      case interval.to_s
      when "monthly" then monthly_price_cents
      when "annual" then annual_price_cents
      when "custom" then nil
      else raise ArgumentError, "unsupported billing interval"
      end
    end
  end
end
