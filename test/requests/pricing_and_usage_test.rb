# frozen_string_literal: true

require "test_helper"

class PricingAndUsageRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    sync_usage_catalog
    @publisher = create_identity_user(display_name: "Commercial Catalog Publisher")
    @catalog_authorization = publish_all_plan_versions(user: @publisher)
    @previous_checkout_resolver = Plans::ComparisonsController.checkout_availability_resolver
  end

  teardown do
    Plans::ComparisonsController.checkout_availability_resolver = @previous_checkout_resolver
    Current.reset
  end

  test "public pricing renders every published plan and every governed entitlement state from read models" do
    get pricing_path

    assert_response :success
    assert_select "article[id^='public-plan-card-']", count: 5
    Plans::Plan.order(:display_order).pluck(:key).each do |key|
      name = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: key }, version: 1).display_name
      assert_select "h2", text: name
    end
    assert_select "#public-feature-comparison-title"
    assert_select "#public-feature-comparison-title + p", text: /Disabled, unavailable and contract-configured/
    assert_select "tbody tr", count: 47
    assert_includes response.body, "EUR 39"
    assert_includes response.body, "Custom pricing"
    assert_includes response.body, "Contract configuration required"
    assert_includes response.body, "Disabled"
    assert_includes response.body, "Prices are display data"
  end

  test "authenticated comparison shows exact current and grandfathered status" do
    owner, = create_subscribed_usage_organization(
      plan_key: "starter",
      slug: "plan-comparison-grandfathered",
      user: @publisher
    )
    version = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 1)
    Administration::Public.retire_plan_version(
      plan_key: "starter",
      version: 1,
      confirmation: "RETIRE starter VERSION 1",
      authorization: @catalog_authorization
    )
    assert_equal "grandfathered", version.reload.status
    authenticate_request(issue_identity_session(user: @publisher))

    get organization_plan_comparison_path(owner.organization.slug)

    assert_response :success
    assert_select ".so-badge", text: "Current plan"
    assert_select ".so-badge", text: "Grandfathered"
    assert_includes response.body, "Existing access"
  end

  test "billing controls require permission and exact provider availability" do
    owner, = create_subscribed_usage_organization(
      plan_key: "starter",
      slug: "plan-comparison-controls",
      user: @publisher
    )
    authenticate_request(issue_identity_session(user: @publisher))

    Plans::ComparisonsController.checkout_availability_resolver = ->(offer:, interval:) { false }
    get organization_plan_comparison_path(owner.organization.slug)
    assert_response :success
    assert_select "[aria-disabled='true']", text: /checkout unavailable/

    Plans::ComparisonsController.checkout_availability_resolver = ->(offer:, interval:) { true }
    get organization_plan_comparison_path(owner.organization.slug)
    assert_response :success
    assert_select "a", text: /Upgrade — Monthly/
    refute_includes response.body, "provider_variant"

    analyst = member_with_role(owner, "analyst")
    reset!
    authenticate_request(issue_identity_session(user: analyst.user))
    get organization_plan_comparison_path(owner.organization.slug)
    assert_response :success
    assert_select "p", text: /Ask a billing administrator/
    assert_select "a", text: /Upgrade — Monthly/, count: 0
  end

  test "usage page distinguishes reserved disabled unlimited and unavailable states" do
    owner, = create_subscribed_usage_organization(
      plan_key: "starter",
      slug: "usage-state-workspace",
      user: @publisher
    )
    now = Time.current
    window = current_credit_window(owner, now: now, reference: "usage-state-period")
    Usage::Public.reserve(
      window: window,
      idempotency_key: "usage-page-temporary-hold",
      quantity: 20,
      source: usage_source(owner),
      expires_at: now + 1.hour,
      at: now
    )
    authenticate_request(issue_identity_session(user: @publisher))

    get organization_usage_path(owner.organization.slug)
    assert_response :success
    assert_select "h1", text: "Usage and reservations"
    assert_select "[role='status']", text: /20.*credits temporarily reserved/
    assert_includes response.body, "Unlimited"
    assert_includes response.body, "immutable local observations"

    disabled, = create_subscribed_usage_organization(
      plan_key: "starter",
      slug: "usage-disabled-workspace",
      user: @publisher
    )
    Entitlements::Public.set_organization_override(
      organization_id: disabled.organization.id,
      entitlement_key: "crawl.credits_monthly",
      value: 0,
      starts_at: now + 2.hours,
      reason: "Request coverage for disabled state",
      source: "support",
      actor_membership: disabled.membership,
      authorization: @catalog_authorization
    )
    Current.reset
    travel_to(now + 3.hours) do
      get organization_usage_path(disabled.organization.slug)
      assert_response :success
      assert_select ".so-badge", text: "Disabled"
    end

    enterprise_user = create_identity_user(display_name: "Contract Usage Viewer")
    enterprise, = create_subscribed_usage_organization(
      plan_key: "enterprise",
      slug: "usage-unavailable-contract",
      user: enterprise_user
    )
    reset!
    authenticate_request(issue_identity_session(user: enterprise_user))
    get organization_usage_path(enterprise.organization.slug)
    assert_response :success
    assert_select ".so-badge", text: "Unavailable"
    assert_includes response.body, "concrete plan or contract limit"
  end

  test "usage and comparison reject a foreign organization before exposing commercial data" do
    owner, = create_subscribed_usage_organization(plan_key: "starter", slug: "commercial-owner")
    foreign, = create_subscribed_usage_organization(plan_key: "growth", slug: "commercial-foreign")
    authenticate_request(issue_identity_session(user: owner.membership.user))

    get organization_usage_path(foreign.organization.slug)
    assert_response :forbidden
    refute_includes response.body, foreign.organization.name

    get organization_plan_comparison_path(foreign.organization.slug)
    assert_response :forbidden
    refute_includes response.body, foreign.organization.name
  end

  test "commercial views contain no plan-name or provider-variant branching" do
    sources = %w[
      app/views/public_pages/pricing.html.erb
      app/views/plans/comparisons/show.html.erb
      app/views/usage/dashboards/show.html.erb
    ].map { |path| Rails.root.join(path).read }.join("\n")

    refute_match(/plan_key\s*(?:==|===|in\?)/, sources)
    refute_match(/provider_variant_id/, sources)
    Plans::Plan::KEYS.each { |key| refute_match(/['\"]#{Regexp.escape(key)}['\"]/, sources) }
  end

  private

  def member_with_role(owner, role_key)
    membership = Tenancy::Public.create_membership(
      actor_membership: owner.membership,
      user: create_identity_user(display_name: "Commercial Read Only")
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

  def current_credit_window(owner, now:, reference:)
    Usage::Public.resolve_window(
      organization_id: owner.organization.id,
      meter_key: "crawl.http_fetch",
      at: now,
      billing_period: Usage::BillingPeriod.new(
        starts_at: now.beginning_of_month,
        ends_at: now.next_month.beginning_of_month,
        time_zone_name: "UTC",
        reference: reference
      )
    )
  end
end
