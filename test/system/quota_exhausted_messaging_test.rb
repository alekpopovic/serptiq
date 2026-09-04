# frozen_string_literal: true

require "application_system_test_case"

class QuotaExhaustedMessagingSystemTest < ApplicationSystemTestCase
  test "exhausted quota pauses new work while existing workspace navigation remains available" do
    Authorization::Public.sync_catalog
    sync_usage_catalog
    user = create_identity_user(display_name: "Quota Exhausted Operator")
    publish_all_plan_versions(user: user)
    owner, = create_subscribed_usage_organization(
      plan_key: "free",
      slug: "quota-exhausted-message",
      user: user
    )
    now = Time.current
    window = Usage::Public.resolve_window(
      organization_id: owner.organization.id,
      meter_key: "crawl.http_fetch",
      at: now,
      billing_period: Usage::BillingPeriod.new(
        starts_at: now.beginning_of_month,
        ends_at: now.next_month.beginning_of_month,
        time_zone_name: "UTC",
        reference: "quota-exhausted-system-period"
      )
    )
    Usage::Public.reserve(
      window: window,
      idempotency_key: "quota-exhausted-system-hold",
      quantity: 500,
      source: usage_source(owner),
      expires_at: now + 1.hour,
      at: now
    )
    authenticate_system_browser(issue_identity_session(user: user))

    visit organization_usage_path(owner.organization.slug)

    assert_text "New metered work is paused"
    assert_text "Existing scans, reports and workspace data remain available"
    assert_link "Compare plans"
    assert_link "Return to existing workspace"
    assert_text(/500.*credits temporarily reserved/)
  end
end
