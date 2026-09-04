# frozen_string_literal: true

require "test_helper"

class BillingCheckoutAvailabilityTest < ActiveSupport::TestCase
  Settings = Data.define(:provider) do
    def fetch(key)
      raise KeyError, key unless key == :billing_provider

      provider
    end
  end

  setup do
    Plans::Public.sync_catalog
    version = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 1)
    @mapping = Billing::PlanProviderMapping.create!(
      plan_version_id: version.id,
      provider: "lemon_squeezy",
      environment: "test",
      currency: "EUR",
      billing_interval: "monthly",
      provider_store_id: "1001",
      provider_product_id: "2001",
      provider_variant_id: "3001"
    )
    @attributes = {
      plan_version_id: version.id,
      currency: "EUR",
      billing_interval: "monthly"
    }
  end

  test "availability requires configured provider and exact active mapping without exposing its variant" do
    available = Billing::CheckoutAvailability.new(
      settings: Settings.new("lemon_squeezy"),
      environment: "test"
    )
    disabled = Billing::CheckoutAvailability.new(settings: Settings.new("disabled"), environment: "test")

    assert available.call(**@attributes)
    refute available.call(**@attributes.merge(billing_interval: "annual"))
    refute disabled.call(**@attributes)

    @mapping.update!(active: false)
    refute available.call(**@attributes)
  end
end
