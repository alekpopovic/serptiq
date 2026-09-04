# frozen_string_literal: true

require "test_helper"

class AdministrationPlanGrandfatheringTest < ActiveSupport::TestCase
  setup do
    Plans::Public.sync_catalog
    @publisher = create_identity_user(display_name: "Grandfather Operator")
    Plans::CatalogAccessGrant.create!(
      user_id: @publisher.id,
      permission: "plan_catalog.publish",
      granted_at: Time.current
    )
    @authorization = Plans::Public.authorize_catalog!(
      user: @publisher,
      permission: "plan_catalog.publish"
    )
    @version = publish_catalog_version(plan_key: "starter", version: 1, authorization: @authorization)
  end

  test "retirement grandfathers active subscribers and hides version from new checkout" do
    organization = create_organization_for(name: "Grandfathered Customer", slug: "grandfathered-customer").organization
    subscription = Billing::Public.create_subscription_reference(
      organization_id: organization.id,
      plan_version_id: @version.id,
      billing_interval: "monthly"
    )

    transitioned = retire

    assert_equal "grandfathered", transitioned.status
    assert_equal @version.id, subscription.reload.plan_version_id
    assert_raises(Billing::SubscriptionConflict) do
      Billing::Public.create_subscription_reference(
        organization_id: create_organization_for(name: "New Customer", slug: "new-customer").organization.id,
        plan_version_id: @version.id,
        billing_interval: "monthly"
      )
    end
    assert Auditing::AuditEvent.exists?(
      action: "plan.version_grandfathered",
      target_id: @version.id,
      metadata: { "operation" => "retire", "status" => "grandfathered", "subscriber_count" => 1 }
    )

    subscription.update!(status: "inactive", ended_at: Time.current)
    assert_equal "retired", retire.status
  end

  test "version with no active subscribers retires directly" do
    transitioned = retire

    assert_equal "retired", transitioned.status
    assert Auditing::AuditEvent.exists?(action: "plan.version_retired", target_id: @version.id)
  end

  private

  def retire
    Administration::Public.retire_plan_version(
      plan_key: "starter",
      version: 1,
      confirmation: "RETIRE starter VERSION 1",
      authorization: @authorization
    )
  end
end
