# frozen_string_literal: true

require "test_helper"

class BillingWebhookIngressTest < ActiveSupport::TestCase
  setup do
    @now = Time.utc(2026, 9, 4, 18)
    @provider = Billing::FakeProvider.new(clock: -> { @now })
    @enqueued = []
    @receiver = Billing::ReceiveWebhook.new(
      provider: @provider,
      environment: "test",
      clock: -> { @now },
      enqueue: ->(id) {
        assert Billing::WebhookEvent.exists?(id), "event must commit before enqueue"
        @enqueued << id
      }
    )
  end

  test "persists the verified exact payload encrypted before enqueue" do
    body = fake_body
    receipt = receive(body)

    assert_equal "accepted", receipt.status
    event = Billing::WebhookEvent.find(receipt.id)
    assert_equal "subscription.created", event.event_type
    assert_equal Digest::SHA256.hexdigest(body), event.payload_checksum
    assert_equal body, event.payload
    refute_includes event.payload_ciphertext, body
    assert_equal "application/json", event.request_headers.fetch("content_type")
    assert_equal body.bytesize, event.request_headers.fetch("content_length")
    assert_match(/\A[0-9a-f]{64}\z/, event.request_headers.fetch("user_agent_digest"))
    refute_includes event.request_headers.to_json, "Webhook Test Agent"
    assert_equal [ event.id ], @enqueued
    refute_includes event.inspect, body
  end

  test "same payload is an idempotent duplicate and conflicting payload is retained as evidence" do
    first = receive(fake_body)
    duplicate = receive(fake_body)
    conflict = receive(fake_body(metadata: { "source" => "modified" }))

    assert_equal "accepted", first.status
    assert_equal "duplicate", duplicate.status
    assert_equal "conflict", conflict.status
    event = Billing::WebhookEvent.find(first.id)
    assert_equal 1, event.duplicate_count
    assert_equal 1, event.conflict_count
    assert_equal fake_body, event.payload
    assert_equal 2, @enqueued.length
    assert_equal 1, Billing::WebhookEvent.count
  end

  test "enqueue outage leaves durable pending evidence for provider retry" do
    receiver = Billing::ReceiveWebhook.new(
      provider: @provider,
      environment: "test",
      clock: -> { @now },
      enqueue: ->(_) { raise "queue unavailable" }
    )

    assert_raises(Billing::WebhookEnqueueFailure) do
      receiver.call(raw_body: fake_body, headers: headers)
    end
    event = Billing::WebhookEvent.sole
    assert_equal "pending", event.state
    assert_equal fake_body, event.payload

    receipt = receive(fake_body)
    assert_equal "duplicate", receipt.status
    assert_equal [ event.id ], @enqueued
  end

  test "inventory exposes bounded operational metadata but no provider reference or payload" do
    receipt = receive(fake_body)
    summary = Billing::Public.webhook_events(limit: 1).sole

    assert_equal receipt.id, summary.id
    assert_equal "pending", summary.state
    refute_respond_to summary, :payload
    refute_respond_to summary, :provider_event_id
    assert_raises(ArgumentError) { Billing::Public.webhook_events(limit: 101) }
    assert_raises(ArgumentError) { Billing::Public.webhook_events(state: "invented") }
  end

  test "cipher detects modified encrypted evidence" do
    event = receive(fake_body).then { |receipt| Billing::WebhookEvent.find(receipt.id) }
    event.update_column(:payload_ciphertext, event.payload_ciphertext.reverse)

    assert_raises(Billing::WebhookPayloadCorrupt) { event.payload }
  end

  private

  def receive(body)
    @receiver.call(raw_body: body, headers: headers)
  end

  def headers
    {
      "X-Fake-Signature" => "valid",
      "Content-Type" => "application/json; charset=utf-8",
      "User-Agent" => "Webhook Test Agent"
    }
  end

  def fake_body(metadata: {})
    JSON.generate(
      id: "event-ingress-001",
      name: "subscription.created",
      occurred_at: @now.iso8601,
      subscription_id: "subscription-001",
      metadata: metadata
    )
  end
end
