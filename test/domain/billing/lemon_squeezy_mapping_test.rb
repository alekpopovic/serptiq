# frozen_string_literal: true

require "test_helper"

class LemonSqueezyMappingTest < ActiveSupport::TestCase
  setup do
    Plans::Public.sync_catalog
    @version = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 1)
    @mapping = Billing::PlanProviderMapping.create!(
      plan_version_id: @version.id,
      provider: "lemon_squeezy",
      environment: "test",
      currency: "EUR",
      billing_interval: "monthly",
      provider_store_id: "1001",
      provider_product_id: "2001",
      provider_variant_id: "3001"
    )
  end

  test "resolves an exact environment store product and variant tuple" do
    mapping = Billing::LemonSqueezyPlanMappingLookup.new(
      environment: "test",
      store_reference: "1001"
    ).call(
      store_reference: "1001",
      product_reference: "2001",
      variant_reference: "3001"
    )

    assert_equal @version.id, mapping.plan_version_id
    assert_equal "EUR", mapping.currency
    assert_equal "monthly", mapping.billing_interval
    assert_equal "[FILTERED]", mapping.as_json.fetch(:store_reference)
    assert_equal "[FILTERED]", mapping.as_json.fetch(:product_reference)
    assert_equal "[FILTERED]", mapping.as_json.fetch(:variant_reference)
  end

  test "fails closed for another environment store product variant or inactive mapping" do
    lookup = Billing::LemonSqueezyPlanMappingLookup.new(environment: "test", store_reference: "1001")
    [
      { store_reference: "1002", product_reference: "2001", variant_reference: "3001" },
      { store_reference: "1001", product_reference: "2002", variant_reference: "3001" },
      { store_reference: "1001", product_reference: "2001", variant_reference: "3002" }
    ].each do |coordinates|
      assert_raises(Billing::ProviderMappingMissing) { lookup.call(**coordinates) }
    end

    @mapping.update!(active: false)
    assert_raises(Billing::ProviderMappingMissing) do
      lookup.call(store_reference: "1001", product_reference: "2001", variant_reference: "3001")
    end
    assert_raises(Billing::ProviderMappingMissing) do
      Billing::LemonSqueezyPlanMappingLookup.new(environment: "production", store_reference: "1001")
        .call(store_reference: "1001", product_reference: "2001", variant_reference: "3001")
    end
  end

  test "model and database require numeric complete Lemon Squeezy coordinates" do
    invalid = Billing::PlanProviderMapping.new(
      plan_version_id: @version.id,
      provider: "lemon_squeezy",
      environment: "production",
      currency: "EUR",
      billing_interval: "annual",
      provider_store_id: "1001",
      provider_product_id: nil,
      provider_variant_id: "variant-name"
    )
    refute invalid.valid?
    assert invalid.errors[:provider_store_id].any?
    assert invalid.errors[:provider_product_id].any?
    assert invalid.errors[:provider_variant_id].any?

    assert_raises(ActiveRecord::StatementInvalid) do
      Billing::PlanProviderMapping.transaction(requires_new: true) do
        Billing::PlanProviderMapping.insert!({
          plan_version_id: @version.id,
          provider: "lemon_squeezy",
          environment: "production",
          currency: "EUR",
          billing_interval: "annual",
          provider_store_id: nil,
          provider_product_id: nil,
          provider_variant_id: "4001",
          active: true,
          created_at: Time.current,
          updated_at: Time.current
        })
      end
    end
  end
end
