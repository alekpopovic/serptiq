# frozen_string_literal: true

require "test_helper"

class BillingWebhookIngressRequestTest < ActionDispatch::IntegrationTest
  setup do
    @now = Time.utc(2026, 9, 4, 18)
    @secret = "current-sanitized-webhook-secret"
    @previous_secret = "previous-sanitized-webhook-secret"
    @observed_commits = []
    @previous_builder = Billing::WebhookRackEndpoint.receiver_builder
    install_receiver
  end

  teardown do
    Billing::WebhookRackEndpoint.receiver_builder = @previous_builder
  end

  test "accepts exact HMAC bytes and persists before enqueue and acknowledgement" do
    raw = fixture_body
    post_webhook(raw, signature: sign(raw, @secret))

    assert_response :ok
    assert_equal "no-store", response.headers["Cache-Control"]
    event = Billing::WebhookEvent.sole
    assert_equal raw, event.payload
    assert_equal [ event.id ], @observed_commits
    refute_includes event.payload_ciphertext, raw
  end

  test "accepts the explicitly configured previous secret during rotation" do
    raw = fixture_body
    post_webhook(raw, signature: sign(raw, @previous_secret))

    assert_response :ok
    assert_equal 1, Billing::WebhookEvent.count
  end

  test "rejects missing invalid and modified-byte signatures without persistence" do
    raw = fixture_body
    post_webhook(raw, signature: nil)
    assert_response :unauthorized

    post_webhook(raw, signature: "0" * 64)
    assert_response :unauthorized

    post_webhook("#{raw}\n", signature: sign(raw, @secret))
    assert_response :unauthorized
    assert_equal 0, Billing::WebhookEvent.count
    assert_empty @observed_commits
  end

  test "rejects malformed oversized and unsupported-media payloads safely" do
    malformed = "{"
    post_webhook(malformed, signature: sign(malformed, @secret))
    assert_response :unprocessable_entity

    oversized = "x" * (Billing::VerifiedWebhook::MAX_BODY_BYTES + 1)
    post_webhook(oversized, signature: sign(oversized, @secret))
    assert_response :content_too_large

    post lemon_squeezy_billing_webhook_path,
      params: fixture_body,
      headers: { "Content-Type" => "text/plain", "X-Signature" => sign(fixture_body, @secret) }
    assert_response :unsupported_media_type
    assert_equal 0, Billing::WebhookEvent.count
  end

  test "acknowledges byte-identical duplicates and rejects logical conflicts" do
    raw = fixture_body
    post_webhook(raw, signature: sign(raw, @secret))
    assert_response :ok
    post_webhook(raw, signature: sign(raw, @secret))
    assert_response :ok

    modified = raw.sub('"status": "active"', '"status": "paused"')
    post_webhook(modified, signature: sign(modified, @secret))
    assert_response :conflict
    event = Billing::WebhookEvent.sole
    assert_equal 1, event.duplicate_count
    assert_equal 1, event.conflict_count
    assert_equal raw, event.payload
  end

  test "returns unavailable after a committed record when queue enqueue fails" do
    receiver = build_receiver(enqueue: ->(_) { raise "queue unavailable" })
    Billing::WebhookRackEndpoint.receiver_builder = -> { receiver }
    raw = fixture_body

    post_webhook(raw, signature: sign(raw, @secret))

    assert_response :service_unavailable
    assert_equal "pending", Billing::WebhookEvent.sole.state
  end

  private

  def install_receiver
    receiver = build_receiver(enqueue: ->(id) {
      assert Billing::WebhookEvent.exists?(id)
      @observed_commits << id
    })
    Billing::WebhookRackEndpoint.receiver_builder = -> { receiver }
  end

  def build_receiver(enqueue:)
    provider = Billing::LemonSqueezyProvider.new(
      api_key: "sanitized-api-key",
      webhook_secret: @secret,
      webhook_previous_secret: @previous_secret,
      store_reference: "1001",
      environment: "test",
      clock: -> { @now }
    )
    Billing::ReceiveWebhook.new(
      provider: provider,
      environment: "test",
      clock: -> { @now },
      enqueue: enqueue
    )
  end

  def post_webhook(raw, signature:)
    headers = { "Content-Type" => "application/json", "User-Agent" => "Lemon Webhooks" }
    headers["X-Signature"] = signature if signature
    post lemon_squeezy_billing_webhook_path, params: raw, headers: headers
  end

  def fixture_body
    Rails.root.join(
      "test/fixtures/files/billing/lemon_squeezy/webhook_subscription_created.json"
    ).read
  end

  def sign(body, secret)
    OpenSSL::HMAC.hexdigest("SHA256", secret, body)
  end
end
