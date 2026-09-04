# frozen_string_literal: true

require "test_helper"

class LemonSqueezyProviderTest < ActiveSupport::TestCase
  class ScriptedTransport
    attr_reader :calls

    def initialize(*fixtures)
      @fixtures = fixtures
      @calls = []
    end

    def call(**request)
      calls << request
      fixture = @fixtures.shift
      raise "unexpected transport call" unless fixture

      Billing::LemonSqueezy::HttpResponse.new(
        status: 200,
        headers: { "content-type" => "application/vnd.api+json" },
        body: Rails.root.join("test/fixtures/files/billing/lemon_squeezy", fixture).read
      )
    end
  end

  class NoopInstrumentation
    def emit(*, **)
    end
  end

  class Settings
    def initialize
      @values = {
        billing_store_id: "1001",
        billing_http_open_timeout: 1.0,
        billing_http_read_timeout: 2.0,
        billing_http_write_timeout: 3.0,
        billing_http_max_response_bytes: 1024
      }
    end

    def fetch(key)
      @values.fetch(key)
    end

    def secret(key)
      {
        billing_api_key: "sanitized-api-key",
        billing_webhook_secret: "sanitized-webhook-secret",
        billing_webhook_previous_secret: nil
      }.fetch(key)
    end
  end

  setup do
    @now = Time.utc(2026, 9, 4, 12)
    @organization_id = "11111111-1111-4111-8111-111111111111"
    @plan_version_id = "22222222-2222-4222-8222-222222222222"
    @mapping = Billing::PlanMapping.new(
      plan_version_id: @plan_version_id,
      provider: "lemon_squeezy",
      environment: "test",
      currency: "EUR",
      billing_interval: "monthly",
      store_reference: "1001",
      product_reference: "2001",
      variant_reference: "3001"
    )
  end

  test "implements the shared provider operations against sanitized fixtures" do
    transport = ScriptedTransport.new(
      "customer_success.json",
      "checkout_success.json",
      "customer_success.json",
      "subscription_active.json",
      "subscription_active.json",
      "subscription_cancelled.json",
      "subscription_active.json",
      "subscriptions_page_success.json"
    )
    provider = build_provider(transport)

    created_customer = provider.create_customer(request: customer_request)
    checkout = provider.create_checkout(request: checkout_request)
    portal = provider.customer_portal(customer: customer, idempotency_key: "portal-command")
    subscription = provider.fetch_subscription(reference: "4001")
    changed = provider.change_subscription(
      subscription: subscription,
      variant_reference: "3001",
      idempotency_key: "change-command"
    )
    canceled = provider.cancel_subscription(
      subscription: changed,
      idempotency_key: "cancel-command"
    )
    resumed = provider.resume_subscription(
      subscription: canceled,
      idempotency_key: "resume-command"
    )
    page = provider.reconciliation_page(page_number: 1, page_size: 1)

    assert_instance_of Billing::Customer, created_customer
    assert_equal @organization_id, created_customer.organization_id
    assert_instance_of Billing::CheckoutResult, checkout
    assert_instance_of Billing::PortalLink, portal
    assert_equal "active", subscription.status
    assert_equal "active", changed.status
    assert_equal "canceled", canceled.status
    assert canceled.cancel_at_period_end
    assert_equal "provider_updated_at", canceled.metadata.fetch("cancellation_time_source")
    assert_equal "active", resumed.status
    assert_instance_of Billing::SubscriptionPage, page
    assert_equal 2, page.next_page
    assert_equal 2, page.total
    assert_equal 8, transport.calls.length
    assert Billing::Provider::OPERATIONS.all? { |operation| provider.supports?(operation) }

    customer_call = transport.calls.first
    customer_payload = JSON.parse(customer_call.fetch(:body))
    assert_equal "Sanitized Organization", customer_payload.dig("data", "attributes", "name")
    assert_equal "billing@example.test", customer_payload.dig("data", "attributes", "email")
    assert_equal "1001", customer_payload.dig("data", "relationships", "store", "data", "id")

    checkout_call = transport.calls.second
    checkout_payload = JSON.parse(checkout_call.fetch(:body))
    assert_equal "1001", checkout_payload.dig("data", "relationships", "store", "data", "id")
    assert_equal "3001", checkout_payload.dig("data", "relationships", "variant", "data", "id")
    assert_equal @organization_id,
      checkout_payload.dig("data", "attributes", "checkout_data", "custom", "organization_id")
    refute_includes checkout_call.dig(:headers, "X-Request-ID"), checkout_request.idempotency_key
    assert_equal %i[post post get get patch delete patch get], transport.calls.map { |call| call.fetch(:method) }
  end

  test "normalizes provider lifecycle and fails closed on environment and mapping mismatch" do
    expired = build_provider(ScriptedTransport.new("subscription_expired.json"))
      .fetch_subscription(reference: "4001")
    assert_equal "expired", expired.status
    assert_equal "read_only", expired.access_state
    assert_equal @now, expired.ended_at

    wrong_environment = JSON.parse(fixture_body("subscription_active.json"))
    wrong_environment.dig("data", "attributes")["test_mode"] = false
    transport = raw_transport(wrong_environment.to_json)
    error = assert_raises(Billing::ProviderFailure) do
      build_provider(transport).fetch_subscription(reference: "4001")
    end
    assert_equal "malformed_response", error.category

    missing_mapping = ->(**) { raise Billing::ProviderMappingMissing }
    assert_raises(Billing::ProviderMappingMissing) do
      build_provider(ScriptedTransport.new("subscription_active.json"), mapping_lookup: missing_mapping)
        .fetch_subscription(reference: "4001")
    end
  end

  test "supports only provider period-end cancellation" do
    provider = build_provider(ScriptedTransport.new)
    subscription = snapshot
    error = assert_raises(Billing::ProviderFailure) do
      provider.cancel_subscription(
        subscription: subscription,
        idempotency_key: "cancel-now-command",
        at_period_end: false
      )
    end
    assert_equal "unsupported_operation", error.category
  end

  test "verifies exact raw webhook with HMAC and normalizes only allowlisted event metadata" do
    provider = build_provider(ScriptedTransport.new)
    body = fixture_body("webhook_subscription_created.json")
    signature = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, body)
    verified = provider.verify_webhook(raw_body: body, headers: { "X-Signature" => signature })
    event = provider.parse_event(webhook: verified)

    assert_equal "subscription.created", event.name
    assert_equal "5001", event.customer_reference
    assert_equal "4001", event.subscription_reference
    assert_equal "3001", event.variant_reference
    assert_equal @organization_id, event.metadata.fetch("organization_id")
    assert_match(/\Aevent-[0-9a-f]{64}\z/, event.reference)
    refute_includes event.inspect, body

    assert_raises(Billing::ProviderFailure) do
      provider.verify_webhook(raw_body: body, headers: { "X-Signature" => "0" * 64 })
    end
    tampered = body.sub("subscription_created", "invented_event")
    bad_signature = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, tampered)
    malformed = provider.verify_webhook(raw_body: tampered, headers: { "x-signature" => bad_signature })
    error = assert_raises(Billing::ProviderFailure) { provider.parse_event(webhook: malformed) }
    assert_equal "unsupported_event", error.category
  end

  test "accepts only exact bytes signed by the current or controlled previous secret" do
    previous_secret = "previous-sanitized-webhook-secret"
    provider = Billing::LemonSqueezyProvider.new(
      api_key: api_key,
      webhook_secret: webhook_secret,
      webhook_previous_secret: previous_secret,
      store_reference: "1001",
      environment: "test",
      clock: -> { @now }
    )
    body = fixture_body("webhook_subscription_created.json")

    [ webhook_secret, previous_secret ].each do |secret|
      signature = OpenSSL::HMAC.hexdigest("SHA256", secret, body)
      assert_instance_of Billing::VerifiedWebhook,
        provider.verify_webhook(raw_body: body, headers: { "X-Signature" => signature })
    end
    modified = "#{body}\n"
    signature = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, body)
    assert_raises(Billing::ProviderFailure) do
      provider.verify_webhook(raw_body: modified, headers: { "X-Signature" => signature })
    end
  end

  test "inspect and normalized serialization redact credentials IDs links email and payload" do
    transport = ScriptedTransport.new("checkout_success.json")
    provider = build_provider(transport)
    checkout = provider.create_checkout(request: checkout_request)
    serialized = [ provider.inspect, checkout.inspect, checkout.as_json.to_json ].join(" ")

    refute_includes serialized, api_key
    refute_includes serialized, webhook_secret
    refute_includes serialized, "checkout-safe-001"
    refute_includes serialized, "safe-store.lemonsqueezy.com"
    refute_includes serialized, "billing@example.test"
  end

  test "provider registry builds the configured production adapter lazily" do
    provider = Billing::ProviderRegistry.new(environment: "test", settings: Settings.new)
      .fetch("lemon_squeezy")

    assert_instance_of Billing::LemonSqueezyProvider, provider
    assert_equal "lemon_squeezy", provider.provider_key
  end

  private

  def build_provider(transport, mapping_lookup: ->(**) { @mapping })
    Billing::LemonSqueezyProvider.new(
      api_key: api_key,
      webhook_secret: webhook_secret,
      store_reference: "1001",
      environment: "test",
      transport: transport,
      sleeper: ->(_) { },
      clock: -> { @now },
      instrumentation: NoopInstrumentation.new,
      mapping_lookup: mapping_lookup
    )
  end

  def checkout_request
    @checkout_request ||= Billing::CheckoutRequest.new(
      organization_id: @organization_id,
      plan_version_id: @plan_version_id,
      variant_reference: "3001",
      email: "billing@example.test",
      success_url: "https://searchops.example/billing/success",
      cancel_url: "https://searchops.example/billing/cancel",
      idempotency_key: "checkout-local-command"
    )
  end

  def customer_request
    Billing::CustomerRequest.new(
      organization_id: @organization_id,
      name: "Sanitized Organization",
      email: "billing@example.test",
      idempotency_key: "customer-local-command"
    )
  end

  def customer
    Billing::Customer.new(
      provider: "lemon_squeezy",
      reference: "5001",
      organization_id: @organization_id,
      email: "billing@example.test",
      created_at: @now
    )
  end

  def snapshot
    Billing::SubscriptionSnapshot.new(
      provider: "lemon_squeezy",
      customer_reference: "5001",
      subscription_reference: "4001",
      variant_reference: "3001",
      status: "active",
      access_state: "full",
      billing_interval: "monthly",
      currency: "EUR",
      provider_updated_at: @now,
      metadata: { "raw_status" => "active" }
    )
  end

  def raw_transport(body)
    Class.new do
      define_method(:initialize) { |value| @body = value }
      define_method(:call) do |**|
        Billing::LemonSqueezy::HttpResponse.new(
          status: 200,
          headers: { "content-type" => "application/vnd.api+json" },
          body: @body
        )
      end
    end.new(body)
  end

  def fixture_body(name)
    Rails.root.join("test/fixtures/files/billing/lemon_squeezy", name).read
  end

  def api_key
    "sanitized-api-key"
  end

  def webhook_secret
    "sanitized-webhook-secret"
  end
end
