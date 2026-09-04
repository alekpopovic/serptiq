# frozen_string_literal: true

require "digest"
require "test_helper"

class BillingSubscriptionPlanChangeTest < ActiveSupport::TestCase
  setup do
    Current.reset
    sync_usage_catalog
    @now = Time.current.change(usec: 0)
    @user = create_identity_user(display_name: "Plan Change Owner")
    publish_all_plan_versions(user: @user)
    @now += 1.minute
    @owner = create_organization_for(
      user: @user,
      name: "Plan Change Workspace",
      slug: "plan-change-workspace",
      at: @now
    )
    @starter = plan("starter")
    @growth = plan("growth")
    @subscription = Billing::Public.create_subscription_reference(
      organization_id: @owner.organization.id,
      plan_version_id: @starter.id,
      billing_interval: "monthly"
    )
    @customer = Billing::CustomerMapping.create!(
      organization_id: @owner.organization.id,
      provider: "fake",
      environment: "test",
      provider_customer_id: "customer-001"
    )
    create_mapping(@starter, "variant-starter")
    create_mapping(@growth, "variant-growth")
    @subscription.update!(
      billing_customer_id: @customer.id,
      provider: "fake",
      provider_environment: "test",
      provider_subscription_id: "subscription-001",
      provider_updated_at: @now - 1.minute,
      last_synced_at: @now,
      provider_metadata: { "raw_status" => "active" },
      current_period_starts_at: @now.beginning_of_month,
      current_period_ends_at: @now.next_month.beginning_of_month
    )
    bind_subscription
    @provider = Billing::FakeProvider.new(clock: -> { @now })
    @enqueued = []
    @outbox_enqueued = []
  end

  teardown { Current.reset }

  test "immediate upgrade is idempotent and applies only after canonical provider projection" do
    reservation = reserve("before-upgrade")
    command = requester

    requested = request_change(command, @growth, key: "upgrade-command")
    replay = request_change(command, @growth, key: "upgrade-command")

    assert_equal requested.id, replay.id
    assert_equal [ "upgrade", "immediate", "pending", @now ],
      [ requested.direction, requested.effective_policy, requested.state, requested.effective_at ]
    assert_equal 1, Billing::SubscriptionChange.count
    assert_equal [ [ @owner.organization.id, requested.id, @now ] ], @enqueued
    assert_equal 2, @outbox_enqueued.length
    assert_equal 1, @outbox_enqueued.uniq.length
    assert_equal @starter.id, @subscription.reload.plan_version_id
    assert_equal @starter.id, Entitlements::SubscriptionContext.active.sole.plan_version_id

    submitter.call(
      organization_id: @owner.organization.id,
      subscription_change_id: requested.id
    )
    assert_equal "submitted", Billing::SubscriptionChange.find(requested.id).state
    assert_equal "change_subscription", @provider.calls.last.fetch(:operation)

    outcome = project_target(@growth, "variant-growth")

    assert_equal "applied", outcome.result
    assert_equal @growth.id, @subscription.reload.plan_version_id
    assert_equal "applied", Billing::SubscriptionChange.find(requested.id).state
    context = Entitlements::SubscriptionContext.active.sole
    assert_equal @growth.id, context.plan_version_id
    assert_equal @starter.id, reservation.reload.plan_version_id
    assert_equal "held", reservation.state
    assert_equal @growth.id, reserve("after-upgrade").plan_version_id
    assert Auditing::AuditEvent.exists?(action: "billing.subscription_plan_change_applied")
    assert Shared::Events::OutboxEvent.exists?(event_type: "billing.subscription_plan_change_applied")
  end

  test "downgrade stays scheduled through period end and existing reservation snapshot is unchanged" do
    make_current(@growth)
    reservation = reserve("before-downgrade")

    result = request_change(requester, @starter, key: "downgrade-command")

    assert_equal [ "downgrade", "period_end", "scheduled" ],
      [ result.direction, result.effective_policy, result.state ]
    assert_equal @subscription.current_period_ends_at, result.effective_at
    assert_equal [ [ @owner.organization.id, result.id, @subscription.current_period_ends_at ] ], @enqueued
    assert_equal @growth.id, @subscription.reload.plan_version_id
    assert_equal @growth.id, Entitlements::SubscriptionContext.active.sole.plan_version_id
    assert_equal @growth.id, reservation.reload.plan_version_id
    assert_equal "held", reservation.state
  end

  test "same request key with another target and cross-tenant authorization fail closed" do
    request_change(requester, @growth, key: "stable-request")

    conflict = assert_raises(Billing::PlanChangeConflict) do
      request_change(requester, @starter, key: "stable-request")
    end
    assert_equal "billing_plan_change_request_conflict", conflict.reason_code

    foreign = create_organization_for(name: "Foreign Plan Change", slug: "foreign-plan-change")
    assert_raises(Billing::AccessDenied) do
      requester.call(
        actor_membership: @owner.membership,
        organization: foreign.organization,
        target_plan_key: @growth.plan.key,
        target_plan_version_id: @growth.id,
        currency: "EUR",
        billing_interval: "monthly",
        request_key: "foreign-request",
        authorization: authorization
      )
    end
  end

  private

  def requester
    Billing::RequestSubscriptionPlanChange.new(
      provider: @provider,
      environment: "test",
      auditor: Auditing::Public,
      clock: -> { @now },
      digest_secret: "test-plan-change-secret",
      enqueue: ->(organization_id, change_id, at) { @enqueued << [ organization_id, change_id, at ] },
      outbox_enqueue: ->(id) { @outbox_enqueued << id }
    )
  end

  def submitter
    Billing::SubmitSubscriptionPlanChange.new(
      provider_lookup: ->(_key) { @provider },
      auditor: Auditing::Public,
      clock: -> { @now },
      outbox_enqueue: ->(id) { @outbox_enqueued << id }
    )
  end

  def request_change(command, target, key:)
    command.call(
      actor_membership: @owner.membership,
      organization: @owner.organization,
      target_plan_key: target.plan.key,
      target_plan_version_id: target.id,
      currency: "EUR",
      billing_interval: "monthly",
      request_key: key,
      authorization: authorization
    )
  end

  def authorization
    Authorization::Public.decision(
      actor_membership: @owner.membership,
      organization: @owner.organization,
      permission_key: "billing.manage"
    )
  end

  def project_target(target, variant)
    snapshot = Billing::SubscriptionSnapshot.new(
      provider: "fake",
      customer_reference: @customer.provider_customer_id,
      subscription_reference: @subscription.provider_subscription_id,
      variant_reference: variant,
      status: "active",
      access_state: "full",
      billing_interval: "monthly",
      currency: "EUR",
      current_period_starts_at: @subscription.current_period_starts_at,
      current_period_ends_at: @subscription.current_period_ends_at,
      started_at: @subscription.started_at,
      provider_updated_at: @now,
      metadata: { "raw_status" => "active" }
    )
    provider_event = Billing::ProviderEvent.new(
      provider: "fake",
      reference: "event-plan-change-#{target.id}",
      name: "subscription.updated",
      occurred_at: @now,
      customer_reference: @customer.provider_customer_id,
      subscription_reference: @subscription.provider_subscription_id,
      variant_reference: variant,
      subscription_snapshot: snapshot
    )
    Billing::Subscription.transaction do
      Billing::ProjectProviderEvent.new(
        auditor: Auditing::Public,
        clock: -> { @now }
      ).call(webhook_event: webhook_event, provider_event: provider_event)
    end
  end

  def webhook_event
    raw = "{}"
    Billing::WebhookEvent.create!(
      provider: "fake",
      environment: "test",
      provider_event_id: "event-#{SecureRandom.hex(8)}",
      event_type: "subscription.updated",
      payload_checksum: Digest::SHA256.hexdigest(raw),
      payload_ciphertext: Billing::WebhookPayloadCipher.new.encrypt(raw),
      request_headers: { "content_type" => "application/json", "body_bytes" => raw.bytesize },
      state: "pending",
      received_at: @now,
      last_received_at: @now
    )
  end

  def make_current(version)
    Billing::Subscription.transaction do
      @subscription.update!(
        plan_version_id: version.id,
        plan_key_snapshot: version.plan.key,
        plan_version_snapshot: version.version,
        plan_display_name_snapshot: version.display_name,
        currency_snapshot: version.currency,
        pricing_kind_snapshot: version.pricing_kind,
        price_cents_snapshot: version.monthly_price_cents
      )
      bind_subscription
    end
  end

  def bind_subscription
    Entitlements::Public.bind_subscription(
      organization_id: @subscription.organization_id,
      subscription_id: @subscription.id,
      plan_version_id: @subscription.plan_version_id,
      subscription_revision: @subscription.lock_version,
      subscription_status: @subscription.status,
      access_state: @subscription.access_state,
      grace_ends_at: @subscription.grace_ends_at,
      access_expires_at: @subscription.access_expires_at
    )
  end

  def reserve(key)
    window = Usage::Public.resolve_window(
      organization_id: @owner.organization.id,
      meter_key: "crawl.http_fetch",
      at: @now,
      billing_period: Usage::BillingPeriod.new(
        starts_at: @now.beginning_of_month,
        ends_at: @now.next_month.beginning_of_month,
        time_zone_name: "UTC",
        reference: "plan-change-period"
      )
    )
    Usage::Public.reserve(
      window: window,
      idempotency_key: key,
      quantity: 1,
      source: usage_source(@owner),
      expires_at: @now + 1.hour,
      at: @now
    )
  end

  def create_mapping(version, variant)
    Billing::PlanProviderMapping.create!(
      plan_version_id: version.id,
      provider: "fake",
      environment: "test",
      currency: "EUR",
      billing_interval: "monthly",
      provider_variant_id: variant,
      active: true
    )
  end

  def plan(key)
    Plans::PlanVersion.joins(:plan).find_by!(plans: { key: key }, version: 1)
  end
end
