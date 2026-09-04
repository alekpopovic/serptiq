# frozen_string_literal: true

require "test_helper"

class BillingProviderContractTest < ActiveSupport::TestCase
  setup do
    @now = Time.utc(2026, 9, 4, 12)
    @organization_id = deterministic_uuid("organization", "billing-contract")
    @plan_version_id = deterministic_uuid("plan-version", "billing-contract")
    @customer = Billing::Customer.new(
      provider: "fake",
      reference: "customer-001",
      organization_id: @organization_id,
      email: "billing@example.test",
      created_at: @now
    )
    @checkout = Billing::CheckoutRequest.new(
      organization_id: @organization_id,
      plan_version_id: @plan_version_id,
      variant_reference: "variant-001",
      customer_reference: @customer.reference,
      email: @customer.email,
      success_url: "https://app.example.test/billing/success",
      cancel_url: "https://app.example.test/billing/cancel",
      idempotency_key: "checkout-command-001",
      metadata: { "organization_correlation" => "signed-correlation" }
    )
  end

  test "fake implements every provider operation with normalized deterministic results" do
    adapter = Billing::FakeProvider.new(clock: -> { @now })

    checkout = adapter.create_checkout(request: @checkout)
    portal = adapter.customer_portal(customer: @customer, idempotency_key: "portal-command-001")
    subscription = adapter.fetch_subscription(reference: "subscription-001")
    changed = adapter.change_subscription(
      subscription: subscription,
      variant_reference: "variant-002",
      idempotency_key: "change-command-001"
    )
    canceled = adapter.cancel_subscription(
      subscription: changed,
      idempotency_key: "cancel-command-001",
      at_period_end: true
    )
    resumed = adapter.resume_subscription(
      subscription: canceled,
      idempotency_key: "resume-command-001"
    )
    page = adapter.reconciliation_page(page_number: 1, page_size: 100)
    webhook = adapter.verify_webhook(
      raw_body: webhook_body,
      headers: { "X-Fake-Signature" => "valid" }
    )
    event = adapter.parse_event(webhook: webhook)

    assert_instance_of Billing::CheckoutResult, checkout
    assert_instance_of Billing::PortalLink, portal
    assert_instance_of Billing::SubscriptionSnapshot, subscription
    assert_equal "variant-002", changed.variant_reference
    assert canceled.cancel_at_period_end
    assert_equal "canceled", canceled.status
    assert_equal "active", resumed.status
    assert_instance_of Billing::SubscriptionPage, page
    assert_equal 1, page.total
    assert_instance_of Billing::VerifiedWebhook, webhook
    assert_instance_of Billing::ProviderEvent, event
    assert_equal "payment.succeeded", event.name
    assert_equal 9, adapter.calls.size
    assert Billing::Provider::OPERATIONS.all? { |operation| adapter.supports?(operation) }
  end

  test "operation policies retry only safe or idempotent operations within fixed bounds" do
    policies = Billing::Public.operation_policies

    assert_equal Billing::Provider::OPERATIONS.sort, policies.keys.sort
    assert_equal [ "GET", 2, "none" ], policy_tuple(policies.fetch("fetch_subscription"))
    assert_equal [ "GET", 2, "none" ], policy_tuple(policies.fetch("reconciliation_page"))
    %w[create_checkout change_subscription cancel_subscription resume_subscription].each do |operation|
      policy = policies.fetch(operation)
      assert_equal "required", policy.idempotency
      assert_equal 1, policy.safe_retries
    end
    assert_equal 0, policies.fetch("customer_portal").safe_retries
    assert policies.values.all? { |policy| policy.open_timeout == 2.0 }
    assert policies.values.all? { |policy| policy.read_timeout == 5.0 }
    assert policies.values.all? { |policy| policy.max_response_bytes == 524_288 }
  end

  test "deterministic failure scenarios preserve category retryability and no sensitive request data" do
    adapter = Billing::FakeProvider.new(
      clock: -> { @now },
      scenarios: { fetch_subscription: :timeout, create_checkout: :rate_limited }
    )

    timeout = assert_raises(Billing::ProviderFailure) do
      adapter.fetch_subscription(reference: "subscription-secret")
    end
    assert_equal "timeout", timeout.category
    assert timeout.retryable?
    refute_includes timeout.inspect, "subscription-secret"

    limited = assert_raises(Billing::ProviderFailure) do
      adapter.create_checkout(request: @checkout)
    end
    assert_equal "rate_limited", limited.category
    assert_equal 30, limited.retry_after
    assert limited.retryable?
  end

  test "unsupported operations invalid signatures and malformed payloads fail closed" do
    unsupported = Billing::FakeProvider.new(unsupported: [ "change_subscription" ])
    subscription = Billing::FakeProvider.new(clock: -> { @now })
      .fetch_subscription(reference: "subscription-001")
    error = assert_raises(Billing::ProviderFailure) do
      unsupported.change_subscription(
        subscription: subscription,
        variant_reference: "variant-002",
        idempotency_key: "change-command"
      )
    end
    assert_equal "unsupported_operation", error.category
    refute error.retryable?

    signature = assert_raises(Billing::ProviderFailure) do
      unsupported.verify_webhook(raw_body: webhook_body, headers: {})
    end
    assert_equal "signature_invalid", signature.category

    adapter = Billing::FakeProvider.new(clock: -> { @now })
    verified = adapter.verify_webhook(
      raw_body: "{not-json", headers: { "X-Fake-Signature" => "valid" }
    )
    malformed = assert_raises(Billing::ProviderFailure) { adapter.parse_event(webhook: verified) }
    assert_equal "malformed_response", malformed.category
    refute malformed.retryable?
  end

  test "registry permits fake only outside protected environments and rejects unknown providers" do
    assert_instance_of Billing::FakeProvider,
      Billing::Public.provider(provider_key: "fake", registry: Billing::ProviderRegistry.new(environment: "test"))

    assert_raises(Billing::ProviderUnknown) do
      Billing::ProviderRegistry.new(environment: "production").fetch("fake")
    end
    assert_raises(Billing::ProviderUnknown) do
      Billing::ProviderRegistry.new(environment: "test").fetch("invented")
    end
  end

  private

  def webhook_body
    {
      id: "event-001",
      name: "payment.succeeded",
      occurred_at: @now.iso8601,
      customer_id: "customer-001",
      subscription_id: "subscription-001",
      variant_id: "variant-001",
      metadata: { source: "fake_fixture" }
    }.to_json
  end

  def policy_tuple(policy)
    [ policy.http_method, policy.safe_retries, policy.idempotency ]
  end
end
