# frozen_string_literal: true

require "test_helper"

class QuotaReservationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    Current.reset
    sync_usage_catalog
    @now = Time.utc(2026, 9, 4, 14)
    @owner, = create_subscribed_usage_organization(
      plan_key: "free",
      slug: "quota-concurrency"
    )
    @window = Usage::Public.resolve_window(
      organization_id: @owner.organization.id,
      meter_key: "crawl.http_fetch",
      at: @now,
      billing_period: Usage::BillingPeriod.new(
        starts_at: Time.utc(2026, 9, 1),
        ends_at: Time.utc(2026, 10, 1),
        time_zone_name: "UTC",
        reference: "quota-concurrency-period"
      )
    )
    reserve("boundary-existing", 400, deterministic_uuid("scan", "boundary-existing"))
  end

  teardown do
    Current.reset
    truncate_records
  end

  test "PostgreSQL pool lock permits only one racer at the exact quota boundary" do
    outcomes = concurrently(2.times.map do |index|
      -> {
        reserve(
          "boundary-racer-#{index}",
          100,
          deterministic_uuid("scan", "boundary-racer-#{index}")
        )
        "reserved"
      }
    end)

    assert_equal 1, outcomes.count("reserved"), outcomes.inspect
    assert_equal 1, outcomes.count("usage_quota_exceeded"), outcomes.inspect
    assert_empty outcomes.grep(/unexpected/)
    assert_equal BigDecimal("500"), Usage::QuotaReservation.where(state: "held").sum(:held_quantity)
    assert_equal 2, Usage::QuotaReservation.count
    assert_equal 0, Usage::UsageEvent.count
  end

  test "concurrent retry of the same reservation returns one durable hold" do
    source_id = deterministic_uuid("scan", "same-reservation-retry")
    outcomes = concurrently(2.times.map do
      -> { reserve("same-reservation-key", 50, source_id).id }
    end)

    assert_equal 1, outcomes.uniq.length, outcomes.inspect
    assert_empty outcomes.grep(/unexpected/)
    assert_equal 2, Usage::QuotaReservation.count
    assert_equal BigDecimal("450"), Usage::QuotaReservation.where(state: "held").sum(:held_quantity)
  end

  private

  def reserve(key, quantity, source_id)
    Usage::Public.reserve(
      window: @window,
      idempotency_key: key,
      quantity: quantity,
      source: usage_source(@owner, id: source_id),
      expires_at: @now + 1.hour,
      at: @now
    )
  end

  def concurrently(operations)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Current.reset
          ready << true
          start.pop
          results << operation.call
        rescue Usage::QuotaExceeded, Usage::Invalid, Usage::Conflict => error
          results << error.reason_code
        rescue StandardError => error
          results << "unexpected:#{error.class.name}:#{error.message}"
        ensure
          Current.reset
        end
      end
    end
    operations.length.times { ready.pop }
    operations.length.times { start << true }
    threads.each(&:join)
    operations.length.times.map { results.pop }
  end

  def truncate_records
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE usage_meter_definitions, entitlement_definitions, plans, " \
        "organizations, users, audit_events CASCADE"
    )
  end
end
