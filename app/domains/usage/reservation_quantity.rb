# frozen_string_literal: true

module Usage
  class ReservationQuantity
    ZERO = BigDecimal("0").freeze

    def initialize(quantity: Quantity.new)
      @quantity = quantity
    end

    def positive(raw)
      @quantity.call(raw, positive: true)
    end

    def nonnegative(raw)
      return ZERO if raw.instance_of?(Integer) && raw.zero?
      return ZERO if raw.instance_of?(BigDecimal) && raw.zero?

      value = @quantity.call(raw)
      raise Invalid.new(reason_code: "usage_quantity_invalid") if value.negative?

      value
    end

    def billed(raw, weight:, allow_zero: false)
      quantity = allow_zero ? nonnegative(raw) : positive(raw)
      return ZERO if quantity.zero?

      @quantity.call(quantity * BigDecimal(weight.to_s), positive: true)
    end
  end
end
