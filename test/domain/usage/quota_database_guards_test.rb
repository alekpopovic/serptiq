# frozen_string_literal: true

require "test_helper"

class UsageQuotaDatabaseGuardsTest < ActiveSupport::TestCase
  setup do
    sync_usage_catalog
    @now = Time.utc(2026, 9, 4, 16)
    @owner, = create_subscribed_usage_organization(slug: "quota-database-guards")
    @window = Usage::Public.resolve_window(
      organization_id: @owner.organization.id,
      meter_key: "crawl.http_fetch",
      at: @now,
      billing_period: Usage::BillingPeriod.new(
        starts_at: Time.utc(2026, 9, 1),
        ends_at: Time.utc(2026, 10, 1),
        time_zone_name: "UTC",
        reference: "quota-database-guard-period"
      )
    )
    @reservation = Usage::Public.reserve(
      window: @window,
      idempotency_key: "database-guard-hold",
      quantity: 10,
      source: usage_source(@owner),
      expires_at: @now + 1.hour,
      at: @now
    )
  end

  test "database rejects tenant reassignment snapshot mutation and deletion" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Usage::QuotaReservation.transaction(requires_new: true) do
        Usage::QuotaReservation.where(id: @reservation.id).update_all(limit_quantity: 99_999)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Usage::QuotaReservation.transaction(requires_new: true) do
        Usage::QuotaReservation.where(id: @reservation.id).delete_all
      end
    end
  end

  test "operation log is append only" do
    Usage::Public.release_reservation(
      organization_id: @owner.organization.id,
      reservation_id: @reservation.id,
      idempotency_key: "database-guard-release",
      at: @now + 1.minute
    )
    operation = @reservation.operations.first!

    assert_raises(ActiveRecord::ReadOnlyRecord) { operation.update!(quantity: 9) }
    assert_raises(ActiveRecord::StatementInvalid) do
      Usage::ReservationOperation.transaction(requires_new: true) do
        Usage::ReservationOperation.where(id: operation.id).delete_all
      end
    end
  end
end
