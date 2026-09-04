# frozen_string_literal: true

require "test_helper"

class BillingHostedFlowsRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    Plans::Public.sync_catalog
    @user = create_identity_user(display_name: "Billing Request Owner")
    publish_all_plan_versions(user: @user)
    @owner = create_organization_for(user: @user, name: "Billing Request Workspace", slug: "billing-request")
    @target = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "growth" }, version: 1)
    Billing::PlanProviderMapping.create!(
      plan_version_id: @target.id,
      provider: "fake",
      environment: "test",
      currency: "EUR",
      billing_interval: "monthly",
      provider_variant_id: "variant-request-growth-monthly"
    )
    @now = Time.current
    @provider = Billing::FakeProvider.new(clock: -> { @now })
    @previous_checkout_builder = Billing::CheckoutsController.command_builder
    @previous_portal_builder = Billing::PortalsController.command_builder
    Billing::CheckoutsController.command_builder = -> { checkout_command }
    Billing::PortalsController.command_builder = -> {
      Billing::CreateCustomerPortal.new(
        provider: @provider,
        environment: "test",
        auditor: Auditing::Public,
        clock: -> { @now }
      )
    }
    authenticate_request(issue_identity_session(user: @user))
  end

  teardown do
    Billing::CheckoutsController.command_builder = @previous_checkout_builder
    Billing::PortalsController.command_builder = @previous_portal_builder
    Current.reset
  end

  test "checkout redirects only to adapter link with private referrer-safe response" do
    post organization_billing_checkout_path(@owner.organization.slug), params: checkout_params.merge(
      return_to: "https://attacker.example/steal"
    )

    assert_response :see_other
    assert_equal "https://billing.example.test/checkouts/checkout-001", response.location
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "no-cache", response.headers["Pragma"]
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    request_value = @provider.calls.find { |call| call.fetch(:operation) == "create_checkout" }
      .dig(:request, :request)
    assert_equal "https://searchops.test/dashboard/organizations/billing-request/billing/checkout/return",
      request_value.success_url
    refute_includes request_value.success_url, "attacker.example"
  end

  test "checkout rejects missing permission foreign tenant and retired target before provider call" do
    analyst_user = create_identity_user(display_name: "Billing Request Analyst")
    analyst = Tenancy::Public.create_membership(actor_membership: @owner.membership, user: analyst_user)
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: analyst.id,
      role_id: Authorization::Role.find_by!(key: "analyst").id,
      scope_type: "Organization",
      scope_id: @owner.organization.id
    )
    reset!
    authenticate_request(issue_identity_session(user: analyst_user))
    post organization_billing_checkout_path(@owner.organization.slug), params: checkout_params
    assert_response :forbidden
    assert_empty @provider.calls

    foreign = create_organization_for(slug: "billing-request-foreign")
    reset!
    authenticate_request(issue_identity_session(user: foreign.membership.user))
    post organization_billing_checkout_path(@owner.organization.slug), params: checkout_params
    assert_response :forbidden
    assert_empty @provider.calls
  end

  test "browser return is informational and cannot activate or replace subscription" do
    starter = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 1)
    existing = Billing::Public.create_subscription_reference(
      organization_id: @owner.organization.id,
      plan_version_id: starter.id,
      billing_interval: "monthly"
    )

    get organization_billing_checkout_return_path(@owner.organization.slug), params: {
      paid: "true",
      plan_version_id: @target.id,
      provider_customer_id: "attacker-customer"
    }

    assert_response :success
    assert_includes response.body, "Returning here does not prove payment"
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal existing.id, Billing::Subscription.current.find_by!(organization_id: @owner.organization.id).id
    assert_equal starter.id, Billing::Subscription.current.find_by!(organization_id: @owner.organization.id).plan_version_id
    assert_equal 1, Billing::Subscription.where(organization_id: @owner.organization.id).count
  end

  test "portal redirects an authorized mapped customer without exposing its identifier" do
    Billing::Public.register_customer_mapping(
      organization_id: @owner.organization.id,
      provider: "fake",
      environment: "test",
      provider_customer_id: "customer-request-portal"
    )

    post organization_billing_portal_path(@owner.organization.slug), params: {
      return_to: "https://attacker.example/steal"
    }

    assert_response :see_other
    assert_equal "https://billing.example.test/portal/session-001", response.location
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    refute_includes response.body, "customer-request-portal"
  end

  private

  def checkout_command
    Billing::CreateHostedCheckout.new(
      provider: @provider,
      environment: "test",
      application_origin: "https://searchops.test",
      auditor: Auditing::Public,
      clock: -> { @now }
    )
  end

  def checkout_params
    {
      checkout: {
        plan_version_id: @target.id,
        currency: "EUR",
        billing_interval: "monthly"
      }
    }
  end
end
