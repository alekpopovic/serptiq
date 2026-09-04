# frozen_string_literal: true

require "test_helper"

class BillingHostedFlowsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    Plans::Public.sync_catalog
    @publisher = create_identity_user(display_name: "Hosted Billing Publisher")
    @catalog_authorization = publish_all_plan_versions(user: @publisher)
    @owner = create_organization_for(user: @publisher, name: "Hosted Billing Workspace", slug: "hosted-billing")
    @foreign = create_organization_for(slug: "hosted-billing-foreign")
    @target = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "growth" }, version: 1)
    create_mapping(@target, interval: "monthly")
    @now = Time.current
    @provider = Billing::FakeProvider.new(clock: -> { @now })
    @authorization = management_decision(@owner.membership)
    @checkout = checkout_command(@provider)
  end

  test "checkout authorizes exact published target creates customer and records signed redacted handoff" do
    result = create_checkout(request_key: "hosted-checkout-1")

    assert_instance_of Billing::CheckoutResult, result
    assert_equal %w[create_customer create_checkout], @provider.calls.map { |call| call.fetch(:operation) }
    session = Billing::CheckoutSession.sole
    assert_equal "ready", session.state
    assert_equal @owner.organization.id, session.organization_id
    assert_equal @target.id, session.plan_version_id
    assert_equal result.reference, session.provider_checkout_id
    refute Billing::CheckoutSession.column_names.include?("url")

    request = @provider.calls.last.dig(:request, :request)
    assert_equal @owner.organization.id, request.organization_id
    assert_equal @target.id, request.plan_version_id
    assert Billing::CheckoutCorrelation.new.valid?(
      signature: request.metadata.fetch("correlation"),
      organization_id: @owner.organization.id,
      plan_version_id: @target.id,
      checkout_session_id: session.id,
      environment: "test"
    )

    audit = Auditing::AuditEvent.find_by!(action: "billing.checkout_created")
    assert_equal @owner.organization.id, audit.organization_id
    assert_equal session.id, audit.target_id
    refute_includes audit.metadata.to_json, result.url
    refute_includes audit.metadata.to_json, result.reference
  end

  test "active and replayed checkout requests do not call the provider twice" do
    create_checkout(request_key: "same-checkout-request")
    calls = @provider.calls.length

    error = assert_raises(Billing::CheckoutConflict) do
      create_checkout(request_key: "same-checkout-request")
    end

    assert_includes %w[billing_checkout_already_active billing_checkout_request_replayed], error.reason_code
    assert_equal calls, @provider.calls.length
    assert_equal 1, Billing::CheckoutSession.count
  end

  test "existing tenant customer is reused without provider customer discovery or recreation" do
    Billing::Public.register_customer_mapping(
      organization_id: @owner.organization.id,
      provider: "fake",
      environment: "test",
      provider_customer_id: "customer-existing"
    )

    create_checkout(request_key: "reuse-existing-customer")

    assert_equal [ "create_checkout" ], @provider.calls.map { |call| call.fetch(:operation) }
    request = @provider.calls.sole.dig(:request, :request)
    assert_equal "customer-existing", request.customer_reference
  end

  test "permission tenant and retired or mismatched commercial targets fail before provider mutation" do
    analyst = add_role_member(@owner, "analyst")
    assert_raises(Billing::AccessDenied) do
      create_checkout(actor_membership: analyst, request_key: "analyst-checkout")
    end
    assert_raises(Billing::AccessDenied) do
      create_checkout(actor_membership: @foreign.membership, request_key: "foreign-checkout")
    end
    assert_raises(Plans::CatalogTargetUnavailable) do
      create_checkout(currency: "USD", request_key: "wrong-currency")
    end

    Administration::Public.retire_plan_version(
      plan_key: "growth",
      version: 1,
      confirmation: "RETIRE growth VERSION 1",
      authorization: @catalog_authorization
    )
    assert_raises(Plans::CatalogTargetUnavailable) do
      create_checkout(request_key: "retired-checkout")
    end
    assert_empty @provider.calls
  end

  test "portal requires the tenant customer mapping and audits no hosted URL" do
    missing = Billing::CreateCustomerPortal.new(
      provider: @provider,
      environment: "test",
      auditor: Auditing::Public,
      clock: -> { @now }
    )
    assert_raises(Billing::ProviderMappingMissing) do
      missing.call(
        actor_membership: @owner.membership,
        organization: @owner.organization,
        request_key: "portal-missing",
        authorization: @authorization
      )
    end

    Billing::Public.register_customer_mapping(
      organization_id: @owner.organization.id,
      provider: "fake",
      environment: "test",
      provider_customer_id: "customer-portal"
    )
    link = missing.call(
      actor_membership: @owner.membership,
      organization: @owner.organization,
      request_key: "portal-existing",
      authorization: @authorization
    )

    assert_instance_of Billing::PortalLink, link
    audit = Auditing::AuditEvent.find_by!(action: "billing.portal_created")
    assert_equal @owner.organization.id, audit.organization_id
    refute_includes audit.metadata.to_json, link.url
  end

  test "uncertain provider mutation remains active and cannot be automatically repeated" do
    provider = Billing::FakeProvider.new(
      clock: -> { @now },
      scenarios: { create_customer: :timeout }
    )
    command = checkout_command(provider)

    error = assert_raises(Billing::ProviderFailure) do
      command.call(**checkout_attributes(request_key: "uncertain-customer-create"))
    end
    assert_equal "timeout", error.category
    session = Billing::CheckoutSession.sole
    assert_equal "uncertain", session.state
    assert_nil session.provider_checkout_id
    assert_raises(Billing::CheckoutConflict) do
      command.call(**checkout_attributes(request_key: "uncertain-customer-retry"))
    end
    assert_equal 0, provider.calls.length
  end

  test "hosted return URL policy rejects absolute and scheme-relative browser values" do
    policy = Billing::HostedUrlPolicy.new(application_origin: "https://searchops.test")

    assert_equal "https://searchops.test/dashboard/billing", policy.call("/dashboard/billing")
    assert_raises(ArgumentError) { policy.call("https://attacker.example/steal") }
    assert_raises(ArgumentError) { policy.call("//attacker.example/steal") }
  end

  private

  def checkout_command(provider)
    Billing::CreateHostedCheckout.new(
      provider: provider,
      environment: "test",
      application_origin: "https://searchops.test",
      auditor: Auditing::Public,
      clock: -> { @now }
    )
  end

  def create_checkout(actor_membership: @owner.membership, currency: "EUR", request_key:)
    @checkout.call(**checkout_attributes(
      actor_membership: actor_membership,
      currency: currency,
      request_key: request_key
    ))
  end

  def checkout_attributes(actor_membership: @owner.membership, currency: "EUR", request_key:)
    {
      actor_membership: actor_membership,
      organization: @owner.organization,
      plan_version_id: @target.id,
      currency: currency,
      billing_interval: "monthly",
      success_path: "/dashboard/organizations/#{@owner.organization.slug}/billing/checkout/return",
      cancel_path: "/dashboard/organizations/#{@owner.organization.slug}/plans",
      request_key: request_key,
      authorization: management_decision(actor_membership)
    }
  end

  def management_decision(actor_membership)
    Authorization::Public.policy(
      actor_membership: actor_membership,
      organization: @owner.organization
    ).decision(permission_key: "billing.manage")
  end

  def create_mapping(version, interval:)
    Billing::PlanProviderMapping.create!(
      plan_version_id: version.id,
      provider: "fake",
      environment: "test",
      currency: version.currency,
      billing_interval: interval,
      provider_variant_id: "variant-#{version.plan.key}-#{interval}"
    )
  end

  def add_role_member(owner, role_key)
    membership = Tenancy::Public.create_membership(
      actor_membership: owner.membership,
      user: create_identity_user(display_name: "Hosted Billing Analyst")
    )
    Authorization::Public.assign_role(
      actor_membership: owner.membership,
      grantee_type: "Membership",
      grantee_id: membership.id,
      role_id: Authorization::Role.find_by!(key: role_key).id,
      scope_type: "Organization",
      scope_id: owner.organization.id
    )
    membership
  end
end
