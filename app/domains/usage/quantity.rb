# frozen_string_literal: true

require "bigdecimal"

module Usage
  class Quantity
    SCALE = 6
    MAXIMUM = BigDecimal("999999999999999999")

    def call(raw, positive: false)
      value = case raw
      when Integer then BigDecimal(raw.to_s)
      when BigDecimal then raw
      else raise Invalid.new(reason_code: "usage_quantity_invalid")
      end
      valid = value.finite? && !value.zero? && value.abs <= MAXIMUM && decimal_scale(value) <= SCALE
      valid &&= value.positive? if positive
      raise Invalid.new(reason_code: "usage_quantity_invalid") unless valid

      value
    end

    private

    def decimal_scale(value)
      value.frac.to_s("F").delete_prefix("0.").sub(/0+\z/, "").length
    end
  end
end
