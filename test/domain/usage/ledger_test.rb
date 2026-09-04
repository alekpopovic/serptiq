# frozen_string_literal: true

require "test_helper"

class UsageLedgerTest < ActiveSupport::TestCase
  setup do
    sync_usage_catalog
    @owner, = create_subscribed_usage_organization(slug: "usage-ledger")
    @window = resolve_usage_window(@owner)
    @source = usage_source(@owner, id: deterministic_uuid("scan", "ledger"))
    @occurred_at = Time.utc(2026, 1, 15, 12)
  end

  test "same tenant idempotency key returns one event and conflicting replay is rejected" do
    first = record_usage(idempotency_key: "scan-ledger-fetch-1", quantity: 3)
    replay = record_usage(idempotency_key: "scan-ledger-fetch-1", quantity: 3)

    assert_equal first.id, replay.id
    assert_equal 1, Usage::UsageEvent.count
    assert_equal BigDecimal("3"), first.billed_quantity

    error = assert_raises(Usage::Conflict) do
      record_usage(idempotency_key: "scan-ledger-fetch-1", quantity: 4)
    end
    assert_equal "usage_idempotency_conflict", error.reason_code
    assert_equal 1, Usage::UsageEvent.count
  end

  test "events are append only through models and direct SQL" do
    event = record_usage(idempotency_key: "scan-ledger-immutable", quantity: 2)

    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(occurred_at: event.occurred_at + 1.second) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy! }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.delete }
    assert_raises(ActiveRecord::StatementInvalid) do
      Usage::UsageEvent.transaction(requires_new: true) do
        Usage::UsageEvent.where(id: event.id).update_all(quantity: 9)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Usage::UsageEvent.transaction(requires_new: true) do
        Usage::UsageEvent.where(id: event.id).delete_all
      end
    end
  end

  test "weighted aggregate exposes used reserved remaining and immutable plan limit" do
    record_usage(idempotency_key: "scan-ledger-aggregate-1", quantity: 10)
    rendered_window = resolve_usage_window(@owner, meter_key: "crawl.rendered_page")
    Usage::Public.record(
      window: rendered_window,
      idempotency_key: "scan-ledger-rendered-1",
      quantity: 1,
      source: @source,
      occurred_at: @occurred_at
    )
    summary = Usage::Public.summary(
      organization_id: @owner.organization.id,
      window_id: @window.id,
      reserved: BigDecimal("5")
    )

    assert_equal BigDecimal("20"), summary.used
    assert_equal BigDecimal("5"), summary.reserved
    assert_equal BigDecimal("25000"), summary.limit
    assert_equal BigDecimal("24975"), summary.remaining
    refute_predicate summary, :unlimited?
    assert_equal "credits", summary.unit
  end

  test "unlimited observational meter has an explicit nil limit and remaining value" do
    owner = create_organization_for(slug: "usage-unlimited-report")
    window = Usage::Public.resolve_window(
      organization_id: owner.organization.id,
      meter_key: "reports.generated",
      at: @occurred_at
    )
    Usage::Public.record(
      window: window,
      idempotency_key: "report-generated-1",
      quantity: 1,
      source: usage_source(owner, type: "ReportRun"),
      occurred_at: @occurred_at
    )

    summary = Usage::Public.summary(organization_id: owner.organization.id, window_id: window.id)
    assert_predicate summary, :unlimited?
    assert_nil summary.limit
    assert_nil summary.remaining
    assert_equal BigDecimal("1"), summary.used
  end

  test "hostile metadata and events outside the attributed window fail closed" do
    metadata_error = assert_raises(Usage::Invalid) do
      record_usage(
        idempotency_key: "scan-ledger-sensitive-metadata",
        quantity: 1,
        metadata: { access_token: "must-not-persist" }
      )
    end
    assert_equal "usage_metadata_invalid", metadata_error.reason_code
    refute_includes Usage::UsageEvent.all.to_json, "must-not-persist"

    outside = assert_raises(Usage::Invalid) do
      Usage::Public.record(
        window: @window,
        idempotency_key: "scan-ledger-outside-window",
        quantity: 1,
        source: @source,
        occurred_at: @window.ends_at
      )
    end
    assert_equal "usage_event_invalid", outside.reason_code
  end

  private

  def record_usage(idempotency_key:, quantity:, metadata: {})
    Usage::Public.record(
      window: @window,
      idempotency_key: idempotency_key,
      quantity: quantity,
      source: @source,
      occurred_at: @occurred_at,
      metadata: metadata
    )
  end
end
