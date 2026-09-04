# frozen_string_literal: true

require "test_helper"

class EntitlementsTypedValueTest < ActiveSupport::TestCase
  test "boolean values never coerce strings or integers" do
    definition = definition_for("boolean", system_default: false)

    assert_equal true, normalize(definition, true).value
    assert_equal false, normalize(definition, false).value
    assert_malformed(definition, "true")
    assert_malformed(definition, 1)
  end

  test "integer values enforce exact type and inclusive bounds" do
    definition = definition_for("integer", minimum_value: 1, maximum_value: 10, system_default: 1)

    assert_equal 1, normalize(definition, 1).value
    assert_equal 10, normalize(definition, 10).value
    assert_malformed(definition, 1.0)
    assert_reason "entitlement_value_out_of_bounds" do
      normalize(definition, 11)
    end
  end

  test "decimal values require BigDecimal and persist a canonical decimal string" do
    definition = definition_for(
      "decimal", minimum_value: 0, maximum_value: 10, system_default: BigDecimal("0")
    )

    value = normalize(definition, BigDecimal("1.250"))

    assert_equal BigDecimal("1.25"), value.value
    assert_equal "1.25", value.stored_value
    assert_malformed(definition, 1.25)
    assert_malformed(definition, "1.25")
  end

  test "enum and string values are exact and bounded" do
    enum = definition_for("enum", allowed_values: %w[none read], system_default: "none")
    string = definition_for("string", max_length: 5, system_default: "safe")

    assert_equal "read", normalize(enum, "read").value
    assert_malformed(enum, :read)
    assert_malformed(enum, "write")
    assert_equal "safe", normalize(string, "safe").value
    assert_malformed(string, " safe")
    assert_malformed(string, "longer")
  end

  test "custom is an explicit contract-required state and never a numeric sentinel" do
    definition = definition_for(
      "integer", minimum_value: 0, maximum_value: 10, allow_custom: true, system_default: 0
    )

    normalized = normalize(definition, "custom")

    assert_equal "custom", normalized.state
    assert_nil normalized.value
    assert_nil normalized.stored_value
    assert_reason "entitlement_custom_value_forbidden" do
      Entitlements::TypedValue.new.normalize(definition: definition, raw: "custom", custom_allowed: false)
    end
  end

  private

  def normalize(definition, value)
    Entitlements::TypedValue.new.normalize(definition: definition, raw: value)
  end

  def assert_malformed(definition, value)
    assert_reason("entitlement_value_malformed") { normalize(definition, value) }
  end

  def assert_reason(reason)
    error = assert_raises(Entitlements::OverrideInvalid) { yield }
    assert_equal reason, error.reason_code
  end

  def definition_for(value_type, **overrides)
    Entitlements::DefinitionSpec.new(**{
      key: "test.value",
      value_type: value_type,
      unit: "units",
      category: "testing",
      minimum_value: nil,
      maximum_value: nil,
      allowed_values: [],
      max_length: nil,
      allow_custom: false,
      security_sensitive: false,
      system_default: nil,
      customer_description: "Test value",
      catalog_checksum: "a" * 64
    }.merge(overrides))
  end
end
