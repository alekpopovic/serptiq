# frozen_string_literal: true

require "test_helper"

class BillingWebhookProjectionTest < ActiveSupport::TestCase
  setup do
    Plans::Public.sync_catalog
    publish_all_plan_versions
    @now = Time.utc(2026, 9, 4, 18)
    @owner = create_organization_for(name: "Webhook Projection", slug: "webhook-projection")
    @plan = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 1)
    create_plan_mapping
    @customer = create_customer_mapping
    @provider = Billing::LemonSqueezyProvider.new(
      api_key: "sanitized-api-key",
      webhook_secret: "sanitized-webhook-secret",
      store_reference: "1001",
      environment: "test",
      clock: -> { @now }
    )
  end

  test "projects a subscription snapshot once and invalidates entitlement context after canonical change" do
    event = ingest(subscription_body(event: "subscription_created", status: "active", updated_at: at(12)))

    outcome = process(event)

    assert_equal "applied", outcome.result
    subscription = Billing::Subscription.sole
    assert_equal @owner.organization.id, subscription.organization_id
    assert_equal @plan.id, subscription.plan_version_id
    assert_equal "active", subscription.status
    assert_equal "full", subscription.access_state
    assert_equal at(12), subscription.provider_updated_at
    context = Entitlements::SubscriptionContext.active.sole
    assert_equal subscription.id, context.subscription_id
    assert_equal subscription.lock_version, context.subscription_revision
    assert_equal "processed", event.reload.state
    assert_equal "applied", event.processing_result
    assert_equal subscription.id, event.subscription_id
    assert_equal 1, event.attempt_count
    audit = Auditing::AuditEvent.find_by!(action: "billing.subscription_projected")
    assert_equal @owner.organization.id, audit.organization_id
    refute_includes audit.metadata.to_json, "4001"
    outbox = Shared::Events::OutboxEvent.find_by!(event_type: "billing.subscription_access_changed")
    assert_equal subscription.id, outbox.aggregate_id
    assert_equal "active", outbox.payload.fetch("status")

    revision = subscription.lock_version
    replay = process(event)
    assert_equal "applied", replay.result
    assert_equal revision, subscription.reload.lock_version
    assert_equal 1, event.reload.attempt_count
  end


  test "past due grace expires deterministically and a newer recovery clears delinquency timing" do
    process(ingest(subscription_body(event: "subscription_created", status: "active", updated_at: at(12))))
    overdue = ingest(subscription_body(event: "subscription_updated", status: "past_due", updated_at: at(13)))

    assert_equal "applied", process(overdue).result
    subscription = Billing::Subscription.sole
    assert_equal [ "past_due", "grace", at(13) + 7.days ],
      [ subscription.status, subscription.access_state, subscription.grace_ends_at ]
    context = Entitlements::SubscriptionContext.active.sole
    assert_equal subscription.grace_ends_at, context.grace_ends_at

    recovered = ingest(subscription_body(event: "subscription_resumed", status: "active", updated_at: at(14)))
    assert_equal "applied", process(recovered).result
    assert_equal [ "active", "full", nil ],
      [ subscription.reload.status, subscription.access_state, subscription.grace_ends_at ]
  end

  test "impossible newer lifecycle transition dead-letters without changing canonical access" do
    process(ingest(subscription_body(event: "subscription_created", status: "active", updated_at: at(12))))
    invalid = ingest(subscription_body(event: "subscription_updated", status: "on_trial", updated_at: at(13)))

    result = process(invalid)

    assert_instance_of Billing::WebhookEventSummary, result
    assert_equal "dead_letter", invalid.reload.state
    assert_equal "subscription_transition_invalid", invalid.last_error_category
    assert_equal [ "active", "full" ], Billing::Subscription.sole.reload.values_at("status", "access_state")
  end

  test "older snapshot cannot downgrade newer canonical subscription or invalidate its entitlement revision" do
    newer = ingest(subscription_body(event: "subscription_paused", status: "paused", updated_at: at(15)))
    process(newer)
    subscription = Billing::Subscription.sole
    entitlement_revision = Entitlements::SubscriptionContext.active.sole.subscription_revision

    stale = ingest(subscription_body(event: "subscription_updated", status: "active", updated_at: at(14)))
    outcome = process(stale)

    assert_equal "stale", outcome.result
    assert_equal "paused", subscription.reload.status
    assert_equal at(15), subscription.provider_updated_at
    assert_equal entitlement_revision,
      Entitlements::SubscriptionContext.active.sole.subscription_revision
    assert_equal "stale", stale.reload.processing_result
  end

  test "equal timestamps use deterministic fail-closed precedence" do
    process(ingest(subscription_body(event: "subscription_created", status: "active", updated_at: at(12))))
    expired = ingest(subscription_body(event: "subscription_expired", status: "expired", updated_at: at(12)))
    process(expired)
    late_active = ingest(subscription_body(event: "subscription_updated", status: "active", updated_at: at(12)))

    assert_equal "stale", process(late_active).result
    subscription = Billing::Subscription.sole
    assert_equal "expired", subscription.status
    assert_equal "read_only", subscription.access_state
    context = Entitlements::SubscriptionContext.active.find_by!(organization_id: @owner.organization.id)
    assert_equal [ "expired", "read_only" ], [ context.subscription_status, context.access_state ]
  end

  test "event arriving before customer mapping retries and later converges without guessing a tenant" do
    owner = create_organization_for(name: "Delayed Mapping", slug: "delayed-mapping")
    event = ingest(subscription_body(
      event: "subscription_created", status: "active", updated_at: at(12), customer_id: 5999
    ))

    assert_raises(Billing::WebhookProjectionRetry) { process(event) }
    assert_equal "retryable", event.reload.state
    assert_equal "customer_mapping_missing", event.last_error_category
    assert_nil event.organization_id
    assert_equal 0, Billing::Subscription.count

    Billing::CustomerMapping.create!(
      organization_id: owner.organization.id,
      provider: "lemon_squeezy", environment: "test", provider_customer_id: "5999"
    )
    replayed = process(event)
    assert_instance_of Billing::WebhookProjectionOutcome, replayed,
      event.reload.slice("state", "last_error_category", "attempt_count").inspect
    assert_equal "applied", replayed.result
    assert_equal "processed", event.reload.state
    assert_equal 2, event.attempt_count
  end

  test "unknown events are retained and ignored while unknown parser versions dead-letter" do
    unknown = ingest(observation_body(event: "license_key_created", type: "license-keys"))
    assert_equal "unknown", unknown.event_type
    assert_equal "ignored", process(unknown).result
    assert_equal "processed", unknown.reload.state
    assert_equal "ignored", unknown.processing_result

    unsupported_version = ingest(subscription_body(
      event: "subscription_created", status: "active", updated_at: at(12)
    ))
    unsupported_version.update_column(:parser_version, 2)
    result = process(unsupported_version)

    assert_instance_of Billing::WebhookEventSummary, result
    assert_equal "dead_letter", unsupported_version.reload.state
    assert_equal "parser_version_unsupported", unsupported_version.last_error_category
  end

  test "order and payment events are correlated observations and never invent lifecycle transitions" do
    subscription_event = ingest(subscription_body(
      event: "subscription_created", status: "active", updated_at: at(12)
    ))
    process(subscription_event)
    subscription = Billing::Subscription.sole
    revision = subscription.lock_version

    payment = ingest(observation_body(
      event: "subscription_payment_failed", type: "subscription-invoices", subscription_id: 4001
    ))
    order = ingest(observation_body(event: "order_created", type: "orders"))

    assert_equal "observed", process(payment).result
    assert_equal "observed", process(order).result
    assert_equal "active", subscription.reload.status
    assert_equal revision, subscription.lock_version
    assert_equal subscription.id, payment.reload.subscription_id
    assert_equal @owner.organization.id, order.reload.organization_id
  end

  test "signed checkout correlation must match exact tenant customer plan and environment" do
    session = checkout_session
    custom = {
      "organization_id" => @owner.organization.id,
      "plan_version_id" => @plan.id,
      "checkout_session_id" => session.id,
      "correlation" => Billing::CheckoutCorrelation.new.sign(
        organization_id: @owner.organization.id,
        plan_version_id: @plan.id,
        checkout_session_id: session.id,
        environment: "test"
      )
    }
    valid = ingest(subscription_body(
      event: "subscription_created", status: "active", updated_at: at(12), custom_data: custom
    ))
    assert_equal "applied", process(valid).result

    foreign = create_organization_for(name: "Foreign Webhook", slug: "foreign-webhook")
    tampered = custom.merge("organization_id" => foreign.organization.id)
    invalid = ingest(subscription_body(
      event: "subscription_updated", status: "active", updated_at: at(13), custom_data: tampered
    ))
    result = process(invalid)

    assert_instance_of Billing::WebhookEventSummary, result
    assert_equal "dead_letter", invalid.reload.state
    assert_equal "checkout_correlation_invalid", invalid.last_error_category
    assert_equal @owner.organization.id, Billing::Subscription.sole.organization_id
  end

  test "dead letters require exact confirmation before controlled replay" do
    event = ingest(subscription_body(event: "subscription_created", status: "active", updated_at: at(12)))
    event.update_column(:parser_version, 2)
    process(event)
    event.reload.update_column(:parser_version, 1)
    enqueued = []
    replayer = Billing::ReplayWebhookEvent.new(
      auditor: Auditing::Public, clock: -> { @now }, enqueue: ->(id) { enqueued << id }
    )

    assert_raises(Billing::WebhookProjectionFailure) do
      replayer.call(webhook_event_id: event.id, confirmation: event.id)
    end
    summary = replayer.call(webhook_event_id: event.id, confirmation: "REPLAY #{event.id}")

    assert_equal "pending", summary.state
    assert_equal [ event.id ], enqueued
    assert_equal 1, event.reload.replay_count
    replayed = process(event)
    assert_instance_of Billing::WebhookProjectionOutcome, replayed,
      event.reload.slice("state", "last_error_category", "attempt_count").inspect
    assert_equal "applied", replayed.result
    assert_equal 2, event.reload.attempt_count
  end

  test "adapter parser covers the supported subscription order and payment matrix" do
    cases = {
      "subscription_created" => "subscription.created",
      "subscription_updated" => "subscription.updated",
      "subscription_cancelled" => "subscription.canceled",
      "subscription_resumed" => "subscription.resumed",
      "subscription_expired" => "subscription.expired",
      "subscription_paused" => "subscription.paused",
      "subscription_unpaused" => "subscription.unpaused",
      "subscription_payment_success" => "payment.succeeded",
      "subscription_payment_failed" => "payment.failed",
      "subscription_payment_recovered" => "payment.recovered",
      "subscription_payment_refunded" => "payment.refunded",
      "order_created" => "order.created",
      "order_refunded" => "order.refunded"
    }
    cases.each do |raw_name, canonical_name|
      raw = if raw_name.start_with?("subscription_") && !raw_name.start_with?("subscription_payment_")
        status = { "subscription_cancelled" => "cancelled", "subscription_expired" => "expired",
          "subscription_paused" => "paused" }.fetch(raw_name, "active")
        subscription_body(event: raw_name, status: status, updated_at: at(12))
      else
        type = raw_name.start_with?("order_") ? "orders" : "subscription-invoices"
        observation_body(event: raw_name, type: type, subscription_id: type == "orders" ? nil : 4001)
      end
      verified = @provider.verify_webhook(raw_body: raw, headers: signature_headers(raw))
      parsed = @provider.parse_event(webhook: verified)
      assert_equal canonical_name, parsed.name
      assert_equal canonical_name.start_with?("subscription."), parsed.subscription_snapshot.present?
    end
  end

  private

  def process(event)
    Billing::ProcessWebhookEvent.new(
      clock: -> { @now },
      projector: Billing::ProjectProviderEvent.new(clock: -> { @now }, auditor: Auditing::Public),
      provider_lookup: ->(key) { key == "lemon_squeezy" ? @provider : raise("unexpected provider") }
    ).call(webhook_event_id: event.id)
  end

  def ingest(raw)
    receiver = Billing::ReceiveWebhook.new(
      provider: @provider, environment: "test", clock: -> { @now }, enqueue: ->(_) { }
    )
    receipt = receiver.call(raw_body: raw, headers: signature_headers(raw))
    Billing::WebhookEvent.find(receipt.id)
  end

  def signature_headers(raw)
    {
      "Content-Type" => "application/json",
      "X-Signature" => OpenSSL::HMAC.hexdigest("SHA256", "sanitized-webhook-secret", raw)
    }
  end

  def subscription_body(event:, status:, updated_at:, custom_data: nil, customer_id: 5001)
    raw_status = status == "on_trial" ? "on_trial" : status
    cancelled = %w[cancelled expired].include?(raw_status)
    pause = raw_status == "paused" ? { "mode" => "void", "resumes_at" => nil } : nil
    payload(event: event, type: "subscriptions", custom_data: custom_data, attributes: {
      "store_id" => 1001, "customer_id" => customer_id, "product_id" => 2001, "variant_id" => 3001,
      "status" => raw_status, "pause" => pause, "cancelled" => cancelled,
      "trial_ends_at" => nil, "ends_at" => cancelled ? updated_at.iso8601 : nil,
      "created_at" => at(10).iso8601, "updated_at" => updated_at.iso8601, "test_mode" => true
    })
  end

  def observation_body(event:, type:, subscription_id: nil)
    attributes = {
      "store_id" => 1001, "customer_id" => 5001,
      "created_at" => at(12).iso8601, "updated_at" => at(12).iso8601, "test_mode" => true
    }
    attributes["subscription_id"] = subscription_id if subscription_id
    payload(event: event, type: type, attributes: attributes)
  end

  def payload(event:, type:, attributes:, custom_data: nil)
    meta = { "event_name" => event, "test_mode" => true }
    meta["custom_data"] = custom_data if custom_data
    JSON.generate("meta" => meta, "data" => { "type" => type, "id" => "4001", "attributes" => attributes })
  end

  def create_plan_mapping
    Billing::PlanProviderMapping.create!(
      plan_version_id: @plan.id,
      provider: "lemon_squeezy", environment: "test", currency: "EUR", billing_interval: "monthly",
      provider_store_id: "1001", provider_product_id: "2001", provider_variant_id: "3001", active: true
    )
  end

  def create_customer_mapping
    Billing::CustomerMapping.create!(
      organization_id: @owner.organization.id,
      provider: "lemon_squeezy", environment: "test", provider_customer_id: "5001"
    )
  end

  def checkout_session
    Billing::CheckoutSession.create!(
      organization_id: @owner.organization.id,
      plan_version_id: @plan.id,
      actor_membership_id: @owner.membership.id,
      billing_customer_id: @customer.id,
      provider: "lemon_squeezy", environment: "test", currency: "EUR", billing_interval: "monthly",
      state: "ready", idempotency_digest: "a" * 64, provider_checkout_id: "checkout-001",
      expires_at: @now + 1.hour, ready_at: @now, created_at: @now
    )
  end

  def at(hour)
    Time.utc(2026, 9, 4, hour)
  end
end
