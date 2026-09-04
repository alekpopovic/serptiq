# frozen_string_literal: true

require "test_helper"

class UsageQuotaReservationMaintenanceJobTest < ActiveJob::TestCase
  setup do
    Current.reset
    sync_usage_catalog
    @now = Time.utc(2026, 9, 4, 12)
    @owner, = create_subscribed_usage_organization(slug: "quota-maintenance")
    period = Usage::BillingPeriod.new(
      starts_at: Time.utc(2026, 9, 1),
      ends_at: Time.utc(2026, 10, 1),
      time_zone_name: "UTC",
      reference: "quota-maintenance-period"
    )
    @window = Usage::Public.resolve_window(
      organization_id: @owner.organization.id,
      meter_key: "crawl.http_fetch",
      at: @now,
      billing_period: period
    )
  end

  teardown { Current.reset }

  test "recurring maintenance expires stale holds and reconciliation is repeatable" do
    reservation = Usage::Public.reserve(
      window: @window,
      idempotency_key: "maintenance-stale-hold",
      quantity: 25_000,
      source: usage_source(@owner),
      expires_at: @now + 5.minutes,
      at: @now
    )

    travel_to(@now + 6.minutes) do
      result = Usage::QuotaReservationMaintenanceJob.perform_now
      assert_equal 1, result.expired_count
      assert_equal 0, result.inconsistency_count
      assert_predicate result, :consistent?

      replay = Usage::QuotaReservationMaintenanceJob.perform_now
      assert_equal 0, replay.expired_count
      assert_predicate replay, :consistent?
    end

    assert reservation.reload.expired?
    assert_equal reservation.held_quantity, reservation.released_quantity
    assert_equal 1, reservation.operations.where(operation_kind: "expire").count
    assert_equal "maintenance", Usage::QuotaReservationMaintenanceJob.new.queue_name

    replacement = Usage::Public.reserve(
      window: @window,
      idempotency_key: "maintenance-replacement-hold",
      quantity: 25_000,
      source: usage_source(@owner),
      expires_at: @now + 2.hours,
      at: @now + 7.minutes
    )
    assert replacement.held?
  end
end
