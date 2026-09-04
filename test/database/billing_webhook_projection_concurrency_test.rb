# frozen_string_literal: true

require "test_helper"

class BillingWebhookProjectionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    Plans::Public.sync_catalog
    publish_all_plan_versions
    @now = Time.utc(2026, 9, 4, 18)
    owner = create_organization_for(name: "Projection Concurrency", slug: "projection-concurrency")
    @plan = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 1)
    Billing::PlanProviderMapping.create!(
      plan_version_id: @plan.id,
      provider: "lemon_squeezy", environment: "test", currency: "EUR", billing_interval: "monthly",
      provider_store_id: "1001", provider_product_id: "2001", provider_variant_id: "3001", active: true
    )
    Billing::CustomerMapping.create!(
      organization_id: owner.organization.id,
      provider: "lemon_squeezy", environment: "test", provider_customer_id: "5001"
    )
    @provider = Billing::LemonSqueezyProvider.new(
      api_key: "sanitized-api-key", webhook_secret: "sanitized-webhook-secret",
      store_reference: "1001", environment: "test", clock: -> { @now }
    )
  end

  teardown { truncate_records }

  test "concurrent equal-time projections converge on deterministic restrictive lifecycle" do
    active = ingest(body(event: "subscription_created", status: "active"))
    expired = ingest(body(event: "subscription_expired", status: "expired"))
    start = Queue.new
    ready = Queue.new
    results = Queue.new
    threads = [ active, expired ].map do |event|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          results << processor.call(webhook_event_id: event.id)
        rescue StandardError => error
          results << error
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)
    outcomes = 2.times.map { results.pop }
    failures = outcomes.grep(Exception)
    flunk(failures.map(&:full_message).join("\n")) if failures.any?

    subscription = Billing::Subscription.sole
    assert_equal "expired", subscription.status
    assert_equal "read_only", subscription.access_state
    assert_equal 100, subscription.provider_event_precedence
    assert_includes [ %w[applied applied], %w[applied stale] ], outcomes.map(&:result).sort
    assert Billing::WebhookEvent.where(state: "processed").count == 2
    context = Entitlements::SubscriptionContext.active.find_by!(organization_id: subscription.organization_id)
    assert_equal "expired", context.subscription_status
    assert_equal "read_only", context.access_state

    assert_raises(ActiveRecord::StatementInvalid) do
      Billing::WebhookEvent.transaction(requires_new: true) do
        active.reload.update_columns(state: "retryable", next_attempt_at: nil)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Billing::Subscription.transaction(requires_new: true) do
        subscription.reload.update_columns(provider_event_precedence: -1)
      end
    end
  end

  private

  def processor
    Billing::ProcessWebhookEvent.new(
      clock: -> { @now },
      projector: Billing::ProjectProviderEvent.new(clock: -> { @now }, auditor: Auditing::Public),
      provider_lookup: ->(_) { @provider }
    )
  end

  def ingest(raw)
    receipt = Billing::ReceiveWebhook.new(
      provider: @provider, environment: "test", clock: -> { @now }, enqueue: ->(_) { }
    ).call(raw_body: raw, headers: {
      "Content-Type" => "application/json",
      "X-Signature" => OpenSSL::HMAC.hexdigest("SHA256", "sanitized-webhook-secret", raw)
    })
    Billing::WebhookEvent.find(receipt.id)
  end

  def body(event:, status:)
    cancelled = status == "expired"
    JSON.generate(
      "meta" => { "event_name" => event, "test_mode" => true },
      "data" => {
        "type" => "subscriptions", "id" => "4001",
        "attributes" => {
          "store_id" => 1001, "customer_id" => 5001, "product_id" => 2001, "variant_id" => 3001,
          "status" => status, "pause" => nil, "cancelled" => cancelled, "trial_ends_at" => nil,
          "ends_at" => cancelled ? Time.utc(2026, 9, 4, 12).iso8601 : nil,
          "created_at" => Time.utc(2026, 9, 4, 10).iso8601,
          "updated_at" => Time.utc(2026, 9, 4, 12).iso8601, "test_mode" => true
        }
      }
    )
  end

  def truncate_records
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE usage_meter_definitions, entitlement_definitions, plans, " \
        "organizations, users, audit_events, billing_webhook_events CASCADE"
    )
  end
end
