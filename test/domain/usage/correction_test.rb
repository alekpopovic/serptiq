# frozen_string_literal: true

require "test_helper"

class UsageCorrectionTest < ActiveSupport::TestCase
  setup do
    sync_usage_catalog
    @owner, = create_subscribed_usage_organization(slug: "usage-corrections")
    @window = resolve_usage_window(@owner)
    @source = usage_source(@owner, id: deterministic_uuid("scan", "correction"))
    @original = Usage::Public.record(
      window: @window,
      idempotency_key: "correction-original",
      quantity: 10,
      source: @source,
      occurred_at: Time.utc(2026, 1, 10)
    )
  end

  test "partial compensating events preserve history and aggregate exactly" do
    first = correct("correction-partial-1", -4)
    replay = correct("correction-partial-1", -4)
    second = correct("correction-partial-2", -6)

    assert_equal first.id, replay.id
    assert_equal @original.id, first.correction_of_event_id
    assert_equal @original.usage_meter_rate_id, first.usage_meter_rate_id
    assert_equal @original.id, second.correction_of_event_id
    assert_equal 3, Usage::UsageEvent.count
    assert_equal BigDecimal("0"), Usage::Public.summary(
      organization_id: @owner.organization.id, window_id: @window.id
    ).used
  end

  test "correction cannot reverse or overcompensate original usage" do
    correct("correction-partial", -4)

    error = assert_raises(Usage::Invalid) { correct("correction-over", -7) }
    assert_equal "usage_correction_invalid", error.reason_code
    error = assert_raises(Usage::Invalid) { correct("correction-wrong-sign", 1) }
    assert_equal "usage_correction_invalid", error.reason_code
    assert_equal BigDecimal("6"), Usage::Public.summary(
      organization_id: @owner.organization.id, window_id: @window.id
    ).used
  end

  test "a correction cannot target another correction or another tenant event" do
    correction = correct("correction-first", -1)
    foreign = create_organization_for(slug: "usage-correction-foreign")

    nested = assert_raises(Usage::Invalid) do
      Usage::Public.correct(
        organization_id: @owner.organization.id,
        event_id: correction.id,
        idempotency_key: "correction-nested",
        quantity: -1,
        reason_code: "duplicate_charge"
      )
    end
    assert_equal "usage_correction_target_invalid", nested.reason_code

    cross_tenant = assert_raises(Usage::Invalid) do
      Usage::Public.correct(
        organization_id: foreign.organization.id,
        event_id: @original.id,
        idempotency_key: "correction-cross-tenant",
        quantity: -1,
        reason_code: "duplicate_charge"
      )
    end
    assert_equal "usage_correction_target_invalid", cross_tenant.reason_code
  end

  private

  def correct(key, quantity)
    Usage::Public.correct(
      organization_id: @owner.organization.id,
      event_id: @original.id,
      idempotency_key: key,
      quantity: quantity,
      reason_code: "duplicate_charge",
      occurred_at: Time.utc(2026, 1, 20)
    )
  end
end
