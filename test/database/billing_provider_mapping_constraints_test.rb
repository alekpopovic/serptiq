# frozen_string_literal: true

require "test_helper"

class BillingProviderMappingConstraintsTest < ActiveSupport::TestCase
  setup do
    sync_usage_catalog
    @owner, = create_subscribed_usage_organization(slug: "billing-provider-constraints")
    @foreign = create_organization_for(slug: "billing-provider-constraints-foreign")
    Billing::Public.register_customer_mapping(
      organization_id: @owner.organization.id,
      provider: "fake",
      environment: "test",
      provider_customer_id: "customer-constraints"
    )
    @customer = Billing::CustomerMapping.sole
    @subscription = Billing::Subscription.current.find_by!(organization_id: @owner.organization.id)
    @now = Time.current.change(usec: 0)
  end

  test "composite foreign key rejects a customer mapping from another tenant" do
    foreign_customer = Billing::CustomerMapping.create!(
      organization_id: @foreign.organization.id,
      provider: "fake",
      environment: "test",
      provider_customer_id: "foreign-customer",
      created_at: @now,
      updated_at: @now
    )
    assert_database_rejects(provider_attributes.merge(billing_customer_id: foreign_customer.id))

    assert_nil @subscription.reload.billing_customer_id
  end

  test "database and model enforce canonical status access timing and provider metadata" do
    @subscription.update!(provider_attributes)
    assert @subscription.provider_backed?
    assert_equal "active", @subscription.provider_metadata.fetch("raw_status")

    assert_database_rejects(status: "active", access_state: "read_only")
    assert_database_rejects(provider_metadata: {})
    assert_database_rejects(status: "incomplete", access_state: "full")
    assert_database_rejects(status: "past_due", access_state: "grace", grace_ends_at: nil)
    assert_database_rejects(status: "canceled", access_state: "full", access_expires_at: nil)
    assert_database_rejects(
      current_period_starts_at: @now + 1.month,
      current_period_ends_at: @now
    )

    @subscription.update!(status: "past_due", access_state: "grace",
      grace_ends_at: @now + 7.days,
      provider_metadata: { "raw_status" => "past_due" })
    @subscription.update!(status: "paused", access_state: "read_only",
      grace_ends_at: nil,
      provider_metadata: { "raw_status" => "paused" })
    @subscription.update!(
      status: "canceled",
      access_state: "full",
      cancel_at_period_end: true,
      canceled_at: @now,
      access_expires_at: @now + 1.month,
      provider_metadata: { "raw_status" => "cancelled" }
    )
    @subscription.update!(
      status: "expired",
      access_state: "read_only",
      ended_at: @now + 1.month,
      access_expires_at: nil,
      provider_metadata: { "raw_status" => "expired" }
    )

    assert_equal "expired", @subscription.status
    assert_equal "read_only", @subscription.access_state
    refute @subscription.current?
  end

  test "provider IDs and customer mappings are unique per environment" do
    foreign_customer = Billing::CustomerMapping.create!(
      organization_id: @foreign.organization.id,
      provider: "fake",
      environment: "development",
      provider_customer_id: "customer-constraints",
      created_at: @now,
      updated_at: @now
    )
    assert foreign_customer.persisted?

    assert_raises(ActiveRecord::StatementInvalid) do
      Billing::CustomerMapping.transaction(requires_new: true) do
        Billing::CustomerMapping.insert!({
          organization_id: @foreign.organization.id,
          provider: "fake",
          environment: "test",
          provider_customer_id: "customer-constraints",
          created_at: @now,
          updated_at: @now
        })
      end
    end

    @subscription.update!(provider_attributes)
    another, = create_subscribed_usage_organization(slug: "billing-provider-identity-second")
    second_customer = Billing::CustomerMapping.create!(
      organization_id: another.organization.id,
      provider: "fake",
      environment: "test",
      provider_customer_id: "customer-second",
      created_at: @now,
      updated_at: @now
    )
    other_subscription = Billing::Subscription.current.find_by!(organization_id: another.organization.id)
    assert_raises(ActiveRecord::RecordNotUnique) do
      other_subscription.update_columns(provider_attributes.merge(
        billing_customer_id: second_customer.id,
        organization_id: another.organization.id
      ))
    end
  end

  private

  def provider_attributes
    {
      billing_customer_id: @customer.id,
      provider: "fake",
      provider_environment: "test",
      provider_subscription_id: "subscription-constraints",
      provider_updated_at: @now,
      last_synced_at: @now,
      provider_metadata: { "raw_status" => "active" },
      current_period_starts_at: @now.beginning_of_month,
      current_period_ends_at: @now.next_month.beginning_of_month
    }
  end

  def assert_database_rejects(attributes)
    assert_raises(ActiveRecord::StatementInvalid) do
      Billing::Subscription.transaction(requires_new: true) do
        @subscription.update_columns(attributes)
      end
    end
  ensure
    @subscription.reload
  end
end
