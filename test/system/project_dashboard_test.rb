# frozen_string_literal: true

require "application_system_test_case"

class ProjectDashboardSystemTest < ApplicationSystemTestCase
  test "ready overview presents accessible real readiness and responsive navigation" do
    sync_usage_catalog
    user = create_identity_user(display_name: "Ready Dashboard Owner")
    owner = create_organization_for(user: user, slug: "ready-dashboard-system")
    enable_onboarding_entitlements(owner, projects: 5, websites: 5, mobile: 5)
    set_onboarding_entitlement(owner, "crawl.credits_monthly", 500, at: Time.current)
    project = create_project_for(owner, slug: "ready-overview")
    property = create_property_for(
      owner,
      project: project,
      display_name: "Production Website",
      configuration: { origin: "https://ready-overview.example.com" }
    )
    property.update!(verification_status: "verified", verified_at: Time.current)
    authenticate_system_browser(issue_identity_session(user: user))

    visit organization_project_path(owner.organization.slug, project.slug)

    assert_selector "main#main-content"
    assert_selector "section[aria-labelledby='readiness-title']"
    assert_selector "turbo-frame#project_scan_status_ready-overview [aria-live='polite']"
    assert_text "Admission ready"
    assert_text "Production Website"
    assert_link "Production"
    assert_text "No persisted scan observation exists yet"
    assert_button "Run baseline scan", disabled: true

    page.current_window.resize_to(390, 844)
    assert_selector "summary[aria-label='Open workspace navigation']", visible: true
    page.current_window.resize_to(1400, 1000)
  end

  test "exhausted quota is distinguished from missing scan evidence" do
    sync_usage_catalog
    user = create_identity_user(display_name: "Exhausted Dashboard Owner")
    owner, = create_subscribed_usage_organization(
      plan_key: "free",
      slug: "exhausted-dashboard-system",
      user: user
    )
    project = create_project_for(owner, slug: "exhausted-overview")
    property = create_property_for(owner, project: project)
    property.update!(verification_status: "verified", verified_at: Time.current)
    now = Time.current
    window = Usage::Public.resolve_window(
      organization_id: owner.organization.id,
      meter_key: "crawl.http_fetch",
      at: now,
      billing_period: Usage::BillingPeriod.new(
        starts_at: now.beginning_of_month,
        ends_at: now.next_month.beginning_of_month,
        time_zone_name: "UTC",
        reference: "dashboard-quota-period"
      )
    )
    Usage::Public.reserve(
      window: window,
      idempotency_key: "dashboard-quota-hold",
      quantity: 500,
      source: usage_source(owner),
      expires_at: now + 1.hour,
      at: now
    )
    authenticate_system_browser(issue_identity_session(user: user))

    visit organization_project_path(owner.organization.slug, project.slug)

    assert_text "Exhausted"
    assert_text "current monthly crawl credit quota is exhausted"
    assert_text "No persisted scan observation exists yet"
    assert_button "Run baseline scan", disabled: true
  end

  test "restricted viewer sees safe explanations and no privileged controls" do
    user = create_identity_user(display_name: "Restricted Dashboard Owner")
    owner = create_organization_for(user: user, slug: "restricted-dashboard-system")
    enable_project_limit(owner, limit: 5)
    project = create_project_for(owner, slug: "restricted-overview")
    viewer_user = create_identity_user(display_name: "Restricted Viewer")
    viewer = Tenancy::Public.create_membership(
      actor_membership: owner.membership,
      user: viewer_user
    )
    Authorization::Public.assign_role(
      actor_membership: owner.membership,
      grantee_type: "Membership",
      grantee_id: viewer.id,
      role_id: Authorization::Role.find_by!(system: true, key: "viewer").id,
      scope_type: "Project",
      scope_id: project.id
    )
    authenticate_system_browser(issue_identity_session(user: viewer_user))

    visit organization_project_path(owner.organization.slug, project.slug)

    assert_text "Your role cannot inspect organization usage"
    assert_text "Your role cannot inspect organization-wide provider connections"
    assert_text "does not include permission to run scans"
    assert_no_link "Edit project"
    assert_no_link "Request deletion"
  end
end
