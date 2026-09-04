# frozen_string_literal: true

require "test_helper"

class EntitlementDiagnosticsRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    Plans::Public.sync_catalog
    Entitlements::Public.sync_catalog
    @owner_user = create_identity_user(display_name: "Entitlement Viewer")
    Plans::CatalogAccessGrant.create!(
      user_id: @owner_user.id, permission: "plan_catalog.publish", granted_at: Time.current
    )
    plan_authorization = Plans::Public.authorize_catalog!(
      user: @owner_user, permission: "plan_catalog.publish"
    )
    version = publish_catalog_version(plan_key: "starter", version: 1, authorization: plan_authorization)
    @owner = create_organization_for(
      user: @owner_user, name: "Entitlement Workspace", slug: "entitlement-workspace"
    )
    Billing::Public.create_subscription_reference(
      organization_id: @owner.organization.id,
      plan_version_id: version.id,
      billing_interval: "monthly"
    )
    authenticate_request(issue_identity_session(user: @owner_user))
  end

  test "authorized tenant sees typed effective values and sources without provider mapping data" do
    Billing::PlanProviderMapping.create!(
      plan_version_id: Entitlements::SubscriptionContext.active.find_by!(
        organization_id: @owner.organization.id
      ).plan_version_id,
      provider: "sandbox",
      environment: "test",
      currency: "EUR",
      billing_interval: "monthly",
      provider_variant_id: "secret-provider-variant"
    )

    get organization_entitlements_path(@owner.organization.slug)

    assert_response :success
    assert_select "h1", text: "Effective entitlements"
    assert_select "tbody tr", count: 47
    assert_includes response.body, "Starter v1"
    assert_includes response.body, "projects.max"
    assert_includes response.body, "Subscribed plan version"
    refute_includes response.body, "secret-provider-variant"
  end

  test "foreign organization and membership without plans permission are denied before diagnostics" do
    foreign = create_organization_for(name: "Foreign Entitlements", slug: "foreign-entitlements")
    get organization_entitlements_path(foreign.organization.slug)
    assert_response :forbidden

    member_user = create_identity_user(display_name: "No Plans Permission")
    Tenancy::Public.create_membership(actor_membership: @owner.membership, user: member_user)
    reset!
    authenticate_request(issue_identity_session(user: member_user))
    get organization_entitlements_path(@owner.organization.slug)
    assert_response :forbidden
  end
end
