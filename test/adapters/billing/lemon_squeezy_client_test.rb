# frozen_string_literal: true

require "test_helper"

class LemonSqueezyClientTest < ActiveSupport::TestCase
  class ScriptedTransport
    attr_reader :calls

    def initialize(*responses)
      @responses = responses
      @calls = []
    end

    def call(**request)
      calls << request
      response = @responses.shift
      raise "unexpected transport call" unless response
      raise response if response.is_a?(Exception)

      response
    end
  end

  class CaptureInstrumentation
    attr_reader :events

    def initialize
      @events = []
    end

    def emit(*, **attributes)
      events << attributes
    end
  end

  class CaptureEmitter
    attr_reader :events

    def initialize
      @events = []
    end

    def emit(event_name, **attributes)
      events << { event_name: event_name }.merge(attributes)
    end
  end

  test "sends exact JSON API authentication correlation and bounded timeout contract" do
    transport = ScriptedTransport.new(success_response("subscription_active.json"))
    client = build_client(transport)

    result = client.update_subscription(
      reference: "4001",
      attributes: { "cancelled" => false },
      operation: "resume_subscription",
      correlation_key: sensitive_idempotency_key
    )

    assert_equal "4001", result.dig("data", "id")
    assert_predicate result, :frozen?
    call = transport.calls.sole
    assert_equal :patch, call.fetch(:method)
    assert_equal URI("https://api.lemonsqueezy.com/v1/subscriptions/4001"), call.fetch(:uri)
    assert_equal "application/vnd.api+json", call.dig(:headers, "Accept")
    assert_equal "Bearer #{sensitive_api_key}", call.dig(:headers, "Authorization")
    assert_match(/\Asearchops-[0-9a-f]{32}\z/, call.dig(:headers, "X-Request-ID"))
    refute_includes call.dig(:headers, "X-Request-ID"), sensitive_idempotency_key
    assert_equal 1.0, call.fetch(:open_timeout)
    assert_equal 2.0, call.fetch(:read_timeout)
    assert_equal 3.0, call.fetch(:write_timeout)
    assert_equal 1024, call.fetch(:max_response_bytes)
    assert_equal false, JSON.parse(call.fetch(:body)).dig("data", "attributes", "cancelled")
  end

  test "retries bounded safe GET failures but never retries mutations" do
    delays = []
    safe = ScriptedTransport.new(
      Net::ReadTimeout.new(sensitive_api_key),
      response(status: 503, fixture: "error_server.json"),
      success_response("subscription_active.json")
    )
    client = build_client(safe, sleeper: ->(delay) { delays << delay })

    assert_equal "4001", client.retrieve_subscription(reference: "4001").dig("data", "id")
    assert_equal 3, safe.calls.length
    assert_equal [ 0.1, 0.2 ], delays

    unsafe = ScriptedTransport.new(
      response(status: 503, fixture: "error_server.json"),
      success_response("subscription_active.json")
    )
    error = assert_raises(Billing::ProviderFailure) do
      build_client(unsafe).cancel_subscription(reference: "4001", correlation_key: "cancel-command")
    end
    assert_equal "unavailable", error.category
    assert_equal 1, unsafe.calls.length
  end

  test "handles bounded rate limit retries and exposes long delay without sleeping" do
    delays = []
    short = ScriptedTransport.new(
      response(status: 429, fixture: "error_rate_limited.json", headers: { "retry-after" => "1" }),
      success_response("subscription_active.json")
    )
    result = build_client(short, sleeper: ->(delay) { delays << delay })
      .retrieve_subscription(reference: "4001")
    assert_equal "4001", result.dig("data", "id")
    assert_equal [ 1 ], delays

    long = ScriptedTransport.new(
      response(status: 429, fixture: "error_rate_limited.json", headers: { "retry-after" => "30" }),
      success_response("subscription_active.json")
    )
    error = assert_raises(Billing::ProviderFailure) do
      build_client(long).retrieve_subscription(reference: "4001")
    end
    assert_equal "rate_limited", error.category
    assert_equal 30, error.retry_after
    assert_equal 1, long.calls.length
  end

  test "maps sanitized provider error fixtures without leaking bodies or credentials" do
    cases = {
      [ 401, "error_unauthorized.json" ] => "authentication",
      [ 403, "error_unauthorized.json" ] => "authorization",
      [ 404, "error_not_found.json" ] => "not_found",
      [ 422, "error_validation.json" ] => "validation",
      [ 429, "error_rate_limited.json" ] => "rate_limited",
      [ 503, "error_server.json" ] => "unavailable"
    }

    cases.each do |(status, fixture), category|
      error = assert_raises(Billing::ProviderFailure) do
        build_client(ScriptedTransport.new(response(status: status, fixture: fixture)))
          .retrieve_customer(reference: "5001")
      end
      assert_equal category, error.category
      refute_includes error.full_message, sensitive_api_key
      refute_includes error.inspect, fixture_body(fixture)
    end
  end

  test "rejects wrong content type invalid JSON oversized response and invalid references" do
    bad_content = response(fixture: "subscription_active.json", content_type: "text/html")
    malformed = response(body: "{not-json")
    too_large = Billing::LemonSqueezy::ResponseTooLarge.new(sensitive_api_key)

    [ bad_content, malformed, too_large ].each do |provider_response|
      error = assert_raises(Billing::ProviderFailure) do
        build_client(ScriptedTransport.new(provider_response)).retrieve_subscription(reference: "4001")
      end
      assert_equal "malformed_response", error.category
      refute_includes error.full_message, sensitive_api_key
    end
    assert_raises(ArgumentError) do
      build_client(ScriptedTransport.new).retrieve_subscription(reference: "../customers/5001")
    end
  end

  test "emits only low-cardinality request metrics without headers body key or PII" do
    emitter = CaptureEmitter.new
    instrumentation = Billing::LemonSqueezy::Instrumentation.new(emitter: emitter)
    transport = ScriptedTransport.new(response(status: 422, fixture: "error_validation.json"))
    assert_raises(Billing::ProviderFailure) do
      build_client(transport, instrumentation: instrumentation).create_checkout(
        payload: { "email" => sensitive_email, "authorization" => sensitive_api_key },
        correlation_key: sensitive_idempotency_key
      )
    end

    serialized = JSON.generate(emitter.events)
    assert_includes serialized, "billing.provider_request"
    assert_includes serialized, "create_checkout"
    assert_includes serialized, "validation"
    refute_includes serialized, sensitive_email
    refute_includes serialized, sensitive_api_key
    refute_includes serialized, sensitive_idempotency_key
    refute_includes serialized, "Authorization"
    refute_includes serialized, "body"
  end

  private

  def build_client(transport, sleeper: ->(_) { }, instrumentation: CaptureInstrumentation.new)
    Billing::LemonSqueezy::Client.new(
      api_key: sensitive_api_key,
      open_timeout: 1.0,
      read_timeout: 2.0,
      write_timeout: 3.0,
      max_response_bytes: 1024,
      transport: transport,
      sleeper: sleeper,
      clock: -> { Time.utc(2026, 9, 4, 12) },
      monotonic_clock: monotonic_clock,
      instrumentation: instrumentation
    )
  end

  def monotonic_clock
    value = 10.0
    -> { value += 0.001 }
  end

  def success_response(fixture)
    response(fixture: fixture)
  end

  def response(status: 200, fixture: nil, body: nil, headers: {}, content_type: "application/vnd.api+json")
    Billing::LemonSqueezy::HttpResponse.new(
      status: status,
      headers: { "content-type" => content_type }.merge(headers),
      body: body || fixture_body(fixture)
    )
  end

  def fixture_body(name)
    Rails.root.join("test/fixtures/files/billing/lemon_squeezy", name).read
  end

  def sensitive_api_key
    "lemon-api-key-that-must-not-leak"
  end

  def sensitive_idempotency_key
    "local-operation-secret-that-must-not-leak"
  end

  def sensitive_email
    "private-customer@example.test"
  end
end
