# frozen_string_literal: true

require "test_helper"
require "stringio"

class BillingConsistencyReportTest < ActiveSupport::TestCase
  setup do
    Current.reset
    sync_usage_catalog
    @owner, = create_subscribed_usage_organization(slug: "billing-consistency")
    @subscription = Billing::Subscription.current.find_by!(organization_id: @owner.organization.id)
    @previous_emitter = Shared::Observability.emitter
  end

  teardown do
    Shared::Observability.emitter = @previous_emitter
    Current.reset
  end

  test "fixture-backed canonical subscription data has no unexplained drift" do
    assert_empty Billing::Public.billing_consistency_issues
  end

  test "entitlement revision drift is reported without mutating either projection" do
    context = Entitlements::SubscriptionContext.active.find_by!(organization_id: @owner.organization.id)
    context.update_column(:subscription_revision, @subscription.lock_version + 1)

    issues = Billing::Public.billing_consistency_issues.index_by(&:type)

    assert_equal 1, issues.fetch("subscription_revision_mismatch").count
    assert_equal @subscription.lock_version, @subscription.reload.lock_version
    assert_equal @subscription.lock_version + 1, context.reload.subscription_revision
  end

  test "operational snapshot emits bounded drift alert metrics" do
    now = Time.utc(2026, 9, 4, 20)
    Billing::ReconciliationRun.create!(
      organization_id: @subscription.organization_id,
      subscription_id: @subscription.id,
      provider: "fake",
      environment: "test",
      source: "scheduled",
      state: "failed",
      failure_category: "provider_unavailable",
      requested_at: now - 1.hour,
      started_at: now - 1.hour,
      completed_at: now,
      attempt_count: 1
    )
    output = StringIO.new
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: Logger.new(output))

    metrics = Billing::OperationalMetrics.new(clock: -> { now }).call(emit: true)

    assert_equal 1, metrics.drift_count
    assert metrics.alerting
    assert_includes output.string, "billing.reconciliation_drift"
    refute_includes output.string, @subscription.id
  end
end
