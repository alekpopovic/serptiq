# frozen_string_literal: true

require "bigdecimal"

module Entitlements
  class TypedValue
    DISABLED_ENUM_VALUES = %w[none disabled].freeze

    def normalize(definition:, raw:, custom_allowed: true)
      if raw == "custom"
        unless custom_allowed && definition.allow_custom
          raise OverrideInvalid.new(reason_code: "entitlement_custom_value_forbidden")
        end

        return NormalizedValue.new(state: "custom", stored_value: nil, value: nil)
      end

      value, stored = configured_value(definition, raw)
      validate_bounds!(definition, value)
      NormalizedValue.new(state: "configured", stored_value: stored, value: value)
    end

    def deserialize(definition:, state:, stored_value:)
      return NormalizedValue.new(state: "custom", stored_value: nil, value: nil) if state == "custom"

      raw = definition.value_type == "decimal" ? BigDecimal(stored_value, exception: false) : stored_value
      normalize(definition: definition, raw: raw, custom_allowed: false)
    rescue ArgumentError, TypeError
      raise OverrideInvalid.new(reason_code: "entitlement_value_malformed"), cause: nil
    end

    def enabled?(definition:, value:)
      case definition.value_type
      when "boolean" then value == true
      when "integer", "decimal" then value.positive?
      when "enum", "string" then !DISABLED_ENUM_VALUES.include?(value)
      else false
      end
    end

    private

    def configured_value(definition, raw)
      case definition.value_type
      when "boolean"
        raise_malformed unless raw.equal?(true) || raw.equal?(false)
        [ raw, raw ]
      when "integer"
        raise_malformed unless raw.instance_of?(Integer)
        [ raw, raw ]
      when "decimal"
        raise_malformed unless raw.instance_of?(BigDecimal) && raw.finite?
        canonical = raw.to_s("F")
        [ raw, canonical ]
      when "enum"
        raise_malformed unless raw.instance_of?(String) && definition.allowed_values.include?(raw)
        [ raw, raw ]
      when "string"
        valid = raw.instance_of?(String) && raw == raw.strip && raw.length.between?(1, definition.max_length)
        raise_malformed unless valid
        [ raw, raw ]
      else
        raise_malformed
      end
    end

    def validate_bounds!(definition, value)
      return unless %w[integer decimal].include?(definition.value_type)

      number = BigDecimal(value.to_s)
      minimum = definition.minimum_value && BigDecimal(definition.minimum_value.to_s)
      maximum = definition.maximum_value && BigDecimal(definition.maximum_value.to_s)
      valid = (!minimum || number >= minimum) && (!maximum || number <= maximum)
      raise OverrideInvalid.new(reason_code: "entitlement_value_out_of_bounds") unless valid
    end

    def raise_malformed
      raise OverrideInvalid.new(reason_code: "entitlement_value_malformed")
    end
  end
end
