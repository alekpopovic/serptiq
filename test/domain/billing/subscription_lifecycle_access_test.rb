# frozen_string_literal: true

require "test_helper"

class BillingSubscriptionLifecycleAccessTest < ActiveSupport::TestCase
  setup do
    Current.reset
    sync_usage_catalog
    @owner, = create_subscribed_usage_organization(slug: "subscription-access-matrix")
    @subscription = Billing::Subscription.current.find_by!(organization_id: @owner.organization.id)
    @now = Time.utc(2026, 9, 4, 12)
  end

  teardown { Current.reset }

  test "state machine permits recovery and corrections while rejecting impossible transitions" do
    allowed = {
      "pending" => %w[pending incomplete trialing active canceled expired],
      "incomplete" => %w[incomplete trialing active canceled expired],
      "trialing" => %w[trialing active past_due paused canceled expired],
      "active" => %w[active past_due paused canceled expired],
      "past_due" => %w[past_due active paused canceled expired],
      "paused" => %w[paused active past_due canceled expired],
      "canceled" => %w[canceled active past_due paused expired],
      "expired" => %w[expired active]
    }

    Billing::SubscriptionLifecycle::STATUSES.product(Billing::SubscriptionLifecycle::STATUSES).each do |from, to|
      assert_equal allowed.fetch(from).include?(to),
        Billing::SubscriptionLifecycle.transition_allowed?(from: from, to: to),
        "#{from} -> #{to}"
    end
    assert Billing::SubscriptionLifecycle.transition_allowed?(from: "canceled", to: "active")
    assert Billing::SubscriptionLifecycle.transition_allowed?(from: "expired", to: "active")
    refute Billing::SubscriptionLifecycle.transition_allowed?(from: "active", to: "trialing")
    refute Billing::SubscriptionLifecycle.transition_allowed?(from: "expired", to: "past_due")
  end

  test "every lifecycle status has an exact read scan integration report and scheduling policy" do
    cases = [
      [ "pending", "pending", {}, [ false, false, false, false, false ] ],
      [ "incomplete", "pending", {}, [ false, false, false, false, false ] ],
      [ "trialing", "full", {}, [ true, true, true, true, true ] ],
      [ "active", "full", {}, [ true, true, true, true, true ] ],
      [ "past_due", "grace", { grace_ends_at: @now + 1.day }, [ true, true, true, true, false ] ],
      [ "paused", "read_only", {}, [ true, false, false, false, false ] ],
      [ "canceled", "full", { access_expires_at: @now + 1.day }, [ true, true, true, true, true ] ],
      [ "expired", "read_only", { ended_at: @now }, [ true, false, false, false, false ] ]
    ]

    cases.each do |status, access, timing, expected|
      project(status, access, **timing)
      actual = [
        access?("scans.read"),
        access?("scans.run", "crawl.manual"),
        access?("integrations.manage", "search_console.enabled"),
        access?("reports.generate", "reports.html"),
        access?("reports.schedule", "reports.scheduled")
      ]
      assert_equal expected, actual, status
      assert access?("billing.manage"), "billing remediation must remain available for #{status}"
    end
  end

  test "grace and scheduled cancellation expire at request time without trusting a stale session cache" do
    project("past_due", "grace", grace_ends_at: @now + 1.hour)
    assert access?("scans.run", "crawl.manual", at: @now + 59.minutes)
    refute access?("scans.run", "crawl.manual", at: @now + 1.hour)
    assert access?("scans.read", at: @now + 1.hour)

    project("canceled", "full", access_expires_at: @now + 2.hours)
    assert access?("reports.generate", "reports.html", at: @now + 119.minutes)
    refute access?("reports.generate", "reports.html", at: @now + 2.hours)
    assert access?("reports.read", at: @now + 2.hours)
  end

  test "a newer past due observation does not extend an existing grace deadline" do
    first_snapshot = subscription_snapshot(status: "past_due", provider_updated_at: @now)
    original_deadline = Billing::SubscriptionLifecycle.transition(
      from: "active", snapshot: first_snapshot, at: @now
    ).grace_ends_at
    newer_snapshot = subscription_snapshot(status: "past_due", provider_updated_at: @now + 1.day)

    transition = Billing::SubscriptionLifecycle.transition(
      from: "past_due",
      snapshot: newer_snapshot,
      at: @now + 1.day,
      current_grace_ends_at: original_deadline
    )

    assert_equal original_deadline, transition.grace_ends_at
  end

  test "unified access boundary denies new work before entitlement and quota for read-only subscription" do
    project("paused", "read_only")
    project_id = deterministic_uuid("project", "subscription-access-boundary")
    Authorization::Public.register_scope(
      organization_id: @owner.organization.id,
      scope_type: "Project",
      scope_id: project_id
    )
    request = Authorization::AccessRequest.new(
      actor_membership: @owner.membership,
      organization: @owner.organization,
      project: project_id,
      permission_key: "scans.run",
      entitlement_key: "crawl.manual"
    )

    decision = Authorization::Public.access_decision(request)

    assert_predicate decision, :deny?
    assert_equal "subscription", decision.stage
    assert_equal "subscription_read_only", decision.reason_code
    assert_equal "entitlement_required", decision.public_error_code
  end

  private

  def subscription_snapshot(status:, provider_updated_at:)
    Billing::SubscriptionSnapshot.new(
      provider: "fake",
      customer_reference: "customer-001",
      subscription_reference: "subscription-001",
      variant_reference: "variant-001",
      status: status,
      access_state: "grace",
      billing_interval: "monthly",
      currency: "EUR",
      provider_updated_at: provider_updated_at,
      metadata: { "raw_status" => status }
    )
  end

  def project(status, access_state, grace_ends_at: nil, access_expires_at: nil, ended_at: nil)
    canceled = status == "canceled"
    @subscription.update!(
      status: status,
      access_state: access_state,
      grace_ends_at: grace_ends_at,
      access_expires_at: access_expires_at,
      ended_at: ended_at,
      cancel_at_period_end: canceled,
      canceled_at: canceled ? @now : nil
    )
    Entitlements::Public.bind_subscription(
      organization_id: @subscription.organization_id,
      subscription_id: @subscription.id,
      plan_version_id: @subscription.plan_version_id,
      subscription_revision: @subscription.lock_version,
      subscription_status: status,
      access_state: access_state,
      grace_ends_at: grace_ends_at,
      access_expires_at: access_expires_at,
      active: true
    )
  end

  def access?(permission, entitlement = nil, at: @now)
    Entitlements::Public.subscription_access(
      organization_id: @owner.organization.id,
      permission_key: permission,
      entitlement_key: entitlement,
      at: at
    ).allow?
  end
end
