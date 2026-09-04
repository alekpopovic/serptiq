# frozen_string_literal: true

require "test_helper"

class BillingReconciliationTest < ActiveSupport::TestCase
  setup do
    Plans::Public.sync_catalog
    publish_all_plan_versions
    @now = Time.utc(2026, 9, 4, 18)
    @provider_updated_at = @now - 1.hour
    @owner = create_organization_for(name: "Reconciliation", slug: "reconciliation")
    @plan = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 1)
    @mapping = Billing::PlanProviderMapping.create!(
      plan_version_id: @plan.id,
      provider: "fake",
      environment: "test",
      currency: "EUR",
      billing_interval: "monthly",
      provider_store_id: "store-001",
      provider_product_id: "product-001",
      provider_variant_id: "variant-001",
      active: true
    )
    @subscription = create_provider_subscription(@owner, reference: "subscription-001")
  end

  test "an exact provider snapshot records a match without changing the canonical revision" do
    run = create_run(@subscription)
    revision = @subscription.lock_version
    provider = fake_provider(snapshot())
    command = reconciler(provider: provider)

    summary = command.call(reconciliation_run_id: run.id)
    duplicate = command.call(reconciliation_run_id: run.id)

    assert_equal "matched", summary.state
    assert_equal "matched", duplicate.state
    assert_empty summary.difference_fields
    assert_equal 1, provider.calls.count { |call| call.fetch(:operation) == "fetch_subscription" }
    assert_equal revision, @subscription.reload.lock_version
    assert_equal @now, @subscription.last_synced_at
    assert Auditing::AuditEvent.exists?(
      organization_id: @owner.organization.id,
      action: "billing.reconciliation_matched",
      target_id: run.id
    )
  end

  test "a newer safe snapshot repairs drift through canonical projection and preserves sanitized evidence" do
    run = create_run(@subscription)
    provider_snapshot = snapshot(
      status: "paused",
      access_state: "read_only",
      provider_updated_at: @now
    )

    summary = reconciler(provider: fake_provider(provider_snapshot)).call(reconciliation_run_id: run.id)

    assert_equal "repaired", summary.state
    assert_includes summary.difference_fields, "status"
    assert_equal [ "paused", "read_only", @now ],
      @subscription.reload.values_at("status", "access_state", "provider_updated_at")
    context = Entitlements::SubscriptionContext.active.find_by!(organization_id: @owner.organization.id)
    assert_equal @subscription.lock_version, context.subscription_revision
    assert_equal [ "paused", "read_only" ], [ context.subscription_status, context.access_state ]
    evidence = run.reload.provider_snapshot
    assert_equal "paused", evidence.fetch("status")
    assert_equal 64, evidence.fetch("subscription_reference_digest").length
    refute_includes evidence.to_json, "subscription-001"
    assert Shared::Events::OutboxEvent.exists?(
      aggregate_id: @subscription.id,
      event_type: "billing.subscription_access_changed"
    )
  end

  test "older provider drift is ambiguous and never overwrites newer canonical state" do
    run = create_run(@subscription)
    older = snapshot(status: "paused", access_state: "read_only", provider_updated_at: @provider_updated_at - 1.minute)

    summary = reconciler(provider: fake_provider(older)).call(reconciliation_run_id: run.id)

    assert_equal "ambiguous", summary.state
    assert_includes summary.difference_fields, "status"
    assert_equal [ "active", "full", @provider_updated_at ],
      @subscription.reload.values_at("status", "access_state", "provider_updated_at")
  end

  test "a newer but impossible lifecycle regression is ambiguous rather than guessed" do
    run = create_run(@subscription)
    impossible = snapshot(status: "trialing", access_state: "full", provider_updated_at: @now)

    summary = reconciler(provider: fake_provider(impossible)).call(reconciliation_run_id: run.id)

    assert_equal "ambiguous", summary.state
    assert_includes summary.difference_fields, "status"
    assert_equal "active", @subscription.reload.status
  end

  test "a deleted provider object is classified missing without changing local state" do
    run = create_run(@subscription)
    provider = Billing::FakeProvider.new(
      clock: -> { @now },
      scenarios: { fetch_subscription: :not_found }
    )

    summary = reconciler(provider: provider).call(reconciliation_run_id: run.id)

    assert_equal "missing", summary.state
    assert_equal "provider_not_found", summary.failure_category
    assert_equal "active", @subscription.reload.status
  end

  test "provider outage uses bounded backoff and eventually becomes a terminal failure" do
    scheduled = []
    run = create_run(@subscription)
    provider = Billing::FakeProvider.new(
      clock: -> { @now },
      scenarios: { fetch_subscription: :unavailable }
    )
    command = reconciler(provider: provider, enqueue_retry: ->(id, at) { scheduled << [ id, at ] })

    first = command.call(reconciliation_run_id: run.id)

    assert_equal "retryable", first.state
    assert_equal @now + 5.minutes, first.next_attempt_at
    assert_equal [ [ run.id, @now + 5.minutes ] ], scheduled

    4.times do
      run.reload.update_columns(state: "retryable", next_attempt_at: @now, updated_at: @now)
      command.call(reconciliation_run_id: run.id)
    end

    assert_equal "failed", run.reload.state
    assert_equal 5, run.attempt_count
    assert_equal "provider_unavailable", run.failure_category
  end

  test "targeted requests enforce platform authorization exact tenancy and provider rate limits" do
    user = create_identity_user(display_name: "Billing Support")
    Billing::SupportAccessGrant.create!(
      user_id: user.id,
      permission: "billing_support.manage",
      granted_at: @now
    )
    decision = Billing::Public.authorize_support!(user: user, permission: "billing_support.manage")
    enqueued = []
    requester = Billing::RequestReconciliation.new(
      auditor: Auditing::Public,
      clock: -> { @now },
      max_per_provider: 1,
      enqueue: ->(id) { enqueued << id }
    )

    assert_raises(Billing::SupportAccessDenied) do
      requester.call(
        organization_id: deterministic_uuid("organization", "wrong"),
        subscription_id: @subscription.id,
        actor_user: user,
        authorization: decision
      )
    end

    first = requester.call(
      organization_id: @owner.organization.id,
      subscription_id: @subscription.id,
      actor_user: user,
      authorization: decision
    )
    assert_equal "queued", first.state
    assert_equal [ first.id ], enqueued

    other = create_organization_for(name: "Other Reconciliation", slug: "other-reconciliation")
    second_subscription = create_provider_subscription(other, reference: "subscription-002")
    error = assert_raises(Billing::ReconciliationRateLimited) do
      requester.call(
        organization_id: other.organization.id,
        subscription_id: second_subscription.id,
        actor_user: user,
        authorization: decision
      )
    end
    assert_equal 1.hour.to_i, error.retry_after
  end

  test "scheduled sweep includes current and recently ended provider subscriptions only" do
    recent_owner = create_organization_for(name: "Recent Ended", slug: "recent-ended")
    recent = create_provider_subscription(recent_owner, reference: "subscription-recent")
    recent.update!(status: "expired", access_state: "read_only", ended_at: @now - 2.days)
    old_owner = create_organization_for(name: "Old Ended", slug: "old-ended")
    old = create_provider_subscription(old_owner, reference: "subscription-old")
    old.update!(status: "expired", access_state: "read_only", ended_at: @now - 31.days)
    requested = []
    requester = Object.new
    requester.define_singleton_method(:scheduled) do |subscription:|
      requested << subscription.id
      subscription.id
    end

    result = Billing::ScheduleReconciliations.new(
      requester: requester,
      clock: -> { @now }
    ).call

    assert_equal [ @subscription.id, recent.id ].sort, result.sort
    refute_includes requested, old.id
  end

  test "scheduled sweep makes an interrupted running reconciliation dispatchable again" do
    run = create_run(@subscription)
    run.update!(
      state: "running",
      attempt_count: 1,
      requested_at: @now - 2.hours,
      started_at: @now - 1.hour,
      enqueued_at: @now - 1.hour,
      updated_at: @now - 1.hour
    )
    requested = []
    requester = Object.new
    requester.define_singleton_method(:scheduled) do |subscription:|
      requested << subscription.id
      subscription.id
    end

    Billing::ScheduleReconciliations.new(requester: requester, clock: -> { @now }).call

    assert_equal "retryable", run.reload.state
    assert_nil run.enqueued_at
    assert_equal @now, run.next_attempt_at
    assert_includes requested, @subscription.id
  end

  private

  def create_provider_subscription(owner, reference:)
    customer = Billing::CustomerMapping.create!(
      organization_id: owner.organization.id,
      provider: "fake",
      environment: "test",
      provider_customer_id: "customer-#{reference}"
    )
    subscription = Billing::Subscription.create!(
      organization_id: owner.organization.id,
      billing_customer_id: customer.id,
      plan_version_id: @plan.id,
      plan_key_snapshot: @plan.plan.key,
      plan_version_snapshot: @plan.version,
      plan_display_name_snapshot: @plan.display_name,
      currency_snapshot: "EUR",
      pricing_kind_snapshot: @plan.pricing_kind,
      price_cents_snapshot: @plan.monthly_price_cents,
      billing_interval: "monthly",
      status: "active",
      access_state: "full",
      started_at: @provider_updated_at - 1.month,
      current_period_starts_at: @provider_updated_at.beginning_of_month,
      current_period_ends_at: @provider_updated_at.next_month.beginning_of_month,
      provider: "fake",
      provider_environment: "test",
      provider_subscription_id: reference,
      provider_updated_at: @provider_updated_at,
      last_synced_at: @provider_updated_at,
      provider_metadata: { "raw_status" => "active" },
      provider_event_precedence: 40,
      provider_event_digest: Digest::SHA256.hexdigest("event-#{reference}")
    )
    Entitlements::Public.bind_subscription(
      organization_id: subscription.organization_id,
      subscription_id: subscription.id,
      plan_version_id: subscription.plan_version_id,
      subscription_revision: subscription.lock_version,
      subscription_status: subscription.status,
      access_state: subscription.access_state,
      active: true
    )
    subscription
  end

  def create_run(subscription)
    Billing::ReconciliationRun.create!(
      organization_id: subscription.organization_id,
      subscription_id: subscription.id,
      provider: subscription.provider,
      environment: subscription.provider_environment,
      source: "scheduled",
      state: "queued",
      requested_at: @now,
      created_at: @now,
      updated_at: @now
    )
  end

  def snapshot(status: "active", access_state: "full", provider_updated_at: @provider_updated_at)
    Billing::SubscriptionSnapshot.new(
      provider: "fake",
      customer_reference: @subscription.customer_mapping.provider_customer_id,
      subscription_reference: @subscription.provider_subscription_id,
      variant_reference: @mapping.provider_variant_id,
      status: status,
      access_state: access_state,
      billing_interval: "monthly",
      currency: "EUR",
      current_period_starts_at: @subscription.current_period_starts_at,
      current_period_ends_at: @subscription.current_period_ends_at,
      started_at: @subscription.started_at,
      provider_updated_at: provider_updated_at,
      metadata: { "raw_status" => status }
    )
  end

  def fake_provider(provider_snapshot)
    Billing::FakeProvider.new(
      clock: -> { @now },
      subscription_snapshots: { @subscription.provider_subscription_id => provider_snapshot }
    )
  end

  def reconciler(provider:, enqueue_retry: ->(_id, _at) { })
    Billing::ReconcileSubscription.new(
      provider_lookup: ->(key) { key == "fake" ? provider : raise("unexpected provider") },
      auditor: Auditing::Public,
      clock: -> { @now },
      enqueue_retry: enqueue_retry,
      outbox_enqueue: ->(_id) { }
    )
  end
end
