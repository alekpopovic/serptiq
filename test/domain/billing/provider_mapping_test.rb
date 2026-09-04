# frozen_string_literal: true

require "test_helper"

class BillingProviderMappingTest < ActiveSupport::TestCase
  setup do
    Plans::Public.sync_catalog
    @owner = create_organization_for(slug: "billing-mapping")
    @foreign = create_organization_for(slug: "billing-mapping-foreign")
    @version = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 1)
    Billing::PlanProviderMapping.create!(
      plan_version_id: @version.id,
      provider: "fake",
      environment: "test",
      currency: "EUR",
      billing_interval: "monthly",
      provider_variant_id: "variant-starter-monthly"
    )
  end

  test "customer mapping is tenant scoped idempotent and immutable" do
    first = Billing::Public.register_customer_mapping(
      organization_id: @owner.organization.id,
      provider: "fake",
      environment: "test",
      provider_customer_id: "customer-001"
    )
    replay = Billing::Public.register_customer_mapping(
      organization_id: @owner.organization.id,
      provider: "fake",
      environment: "test",
      provider_customer_id: "customer-001"
    )

    assert_equal first, replay
    assert_equal "customer-001", first.reference
    assert_equal 1, Billing::CustomerMapping.count
    assert_raises(Billing::ProviderMappingMissing) do
      Billing::Public.register_customer_mapping(
        organization_id: @owner.organization.id,
        provider: "fake",
        environment: "test",
        provider_customer_id: "different-customer"
      )
    end
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      Billing::CustomerMapping.sole.update!(provider_customer_id: "different-customer")
    end
  end

  test "customer and plan lookups fail closed for unknown or cross tenant mappings" do
    Billing::Public.register_customer_mapping(
      organization_id: @owner.organization.id,
      provider: "fake",
      environment: "test",
      provider_customer_id: "customer-001"
    )

    customer = Billing::Public.customer_mapping(
      organization_id: @owner.organization.id,
      provider: "fake",
      environment: "test"
    )
    assert_equal @owner.organization.id, customer.organization_id
    assert_raises(Billing::ProviderMappingMissing) do
      Billing::Public.customer_mapping(
        organization_id: @foreign.organization.id,
        provider: "fake",
        environment: "test"
      )
    end

    mapping = Billing::Public.plan_mapping(
      plan_version_id: @version.id,
      provider: "fake",
      environment: "test",
      currency: "EUR",
      billing_interval: "monthly"
    )
    assert_equal "variant-starter-monthly", mapping.variant_reference
    assert_raises(Billing::ProviderMappingMissing) do
      Billing::Public.plan_mapping(
        plan_version_id: @version.id,
        provider: "fake",
        environment: "test",
        currency: "EUR",
        billing_interval: "annual"
      )
    end
  end

  test "one provider customer cannot be attached to another organization" do
    Billing::Public.register_customer_mapping(
      organization_id: @owner.organization.id,
      provider: "fake",
      environment: "test",
      provider_customer_id: "customer-unique"
    )

    error = assert_raises(Billing::ProviderMappingMissing) do
      Billing::Public.register_customer_mapping(
        organization_id: @foreign.organization.id,
        provider: "fake",
        environment: "test",
        provider_customer_id: "customer-unique"
      )
    end
    assert_equal "billing_customer_mapping_conflict", error.reason_code
    assert_equal 1, Billing::CustomerMapping.count
  end
end
