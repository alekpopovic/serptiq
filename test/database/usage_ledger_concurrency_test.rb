# frozen_string_literal: true

require "test_helper"

class UsageLedgerConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    sync_usage_catalog
    @owner, = create_subscribed_usage_organization(slug: "usage-concurrency")
    @window = resolve_usage_window(@owner)
    @source = usage_source(@owner, id: deterministic_uuid("scan", "concurrent-usage"))
    @occurred_at = Time.utc(2026, 1, 15)
  end

  teardown { truncate_records }

  test "concurrent retry with one idempotency key creates exactly one event" do
    outcomes = concurrently(2.times.map do
      -> {
        Usage::Public.record(
          window: @window,
          idempotency_key: "concurrent-usage-event",
          quantity: 3,
          source: @source,
          occurred_at: @occurred_at
        ).id
      }
    end)

    assert_equal 1, outcomes.uniq.length, outcomes.inspect
    assert_empty outcomes.grep(/unexpected/)
    assert_equal 1, Usage::UsageEvent.count
  end

  test "concurrent corrections cannot cumulatively overcompensate the original" do
    original = Usage::Public.record(
      window: @window,
      idempotency_key: "concurrent-correction-original",
      quantity: 10,
      source: @source,
      occurred_at: @occurred_at
    )
    outcomes = concurrently(2.times.map do |index|
      -> {
        Usage::Public.correct(
          organization_id: @owner.organization.id,
          event_id: original.id,
          idempotency_key: "concurrent-correction-#{index}",
          quantity: -6,
          reason_code: "duplicate_charge"
        )
        "corrected"
      }
    end)

    assert_equal 1, outcomes.count("corrected"), outcomes.inspect
    assert_equal 1, outcomes.count("usage_correction_invalid"), outcomes.inspect
    assert_empty outcomes.grep(/unexpected/)
    assert_equal BigDecimal("4"), Usage::UsageEvent.where(usage_window_id: @window.id).sum(:billed_quantity)
  end

  private

  def concurrently(operations)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          results << operation.call
        rescue Usage::Invalid, Usage::Conflict => error
          results << error.reason_code
        rescue StandardError => error
          results << "unexpected:#{error.class.name}:#{error.message}"
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
