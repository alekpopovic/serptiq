# frozen_string_literal: true

require "test_helper"

class UsageQuotaReservationTest < ActiveSupport::TestCase
  setup do
    Current.reset
    sync_usage_catalog
    @now = Time.utc(2026, 9, 4, 10)
    @owner, @authorization = create_subscribed_usage_organization(slug: "quota-reservations")
    @window = usage_window_for(@owner, at: @now, reference: "quota-period-september")
    @source = usage_source(@owner, id: deterministic_uuid("scan", "quota-reservation"))
  end

  teardown { Current.reset }

  test "reserve is idempotent and exposes durable reserved balance" do
    first = reserve(key: "reserve-once", quantity: 20)
    replay = reserve(key: "reserve-once", quantity: 20)

    assert_equal first.id, replay.id
    assert_equal "held", first.state
    assert_equal BigDecimal("20"), first.requested_quantity
    assert_equal BigDecimal("20"), first.held_quantity
    assert_equal "capped", first.limit_kind
    assert_equal BigDecimal("25000"), first.limit_quantity
    assert_equal "subscribed_plan_version", first.entitlement_provenance
    assert_equal 1, Usage::QuotaReservation.count

    summary = Usage::Public.summary(
      organization_id: @owner.organization.id,
      window_id: @window.id,
      at: @now
    )
    assert_equal BigDecimal("20"), summary.reserved
    assert_equal BigDecimal("24980"), summary.remaining

    error = assert_raises(Usage::Conflict) { reserve(key: "reserve-once", quantity: 21) }
    assert_equal "usage_reservation_idempotency_conflict", error.reason_code
  end

  test "quota denial returns bounded structured capacity details and creates no charge" do
    reserve(key: "reserve-near-limit", quantity: 24_995)

    error = assert_raises(Usage::QuotaExceeded) do
      reserve(key: "reserve-over-limit", quantity: 6, source_id: deterministic_uuid("scan", "denied"))
    end
    denial = error.denial
    assert_equal BigDecimal("25000"), denial.limit
    assert_equal BigDecimal("0"), denial.used
    assert_equal BigDecimal("24995"), denial.reserved
    assert_equal BigDecimal("6"), denial.requested
    assert_equal @window.ends_at, denial.reset_at
    assert_equal "usage_quota_exceeded", denial.reason_code
    assert_equal %i[limit meter pool reason_code requested reserved reset_at unit used],
      denial.as_json.keys.sort
    assert_equal 1, Usage::QuotaReservation.count
    assert_equal 0, Usage::UsageEvent.count
  end

  test "extension and partial finalization are idempotent and append actual usage once" do
    reservation = reserve(key: "reserve-lifecycle", quantity: 10)
    extended = Usage::Public.extend_reservation(
      organization_id: @owner.organization.id,
      reservation_id: reservation.id,
      idempotency_key: "extend-lifecycle",
      additional_quantity: 5,
      expires_at: @now + 2.hours,
      at: @now + 1.minute
    )
    replay_extension = Usage::Public.extend_reservation(
      organization_id: @owner.organization.id,
      reservation_id: reservation.id,
      idempotency_key: "extend-lifecycle",
      additional_quantity: 5,
      expires_at: @now + 2.hours,
      at: @now + 2.minutes
    )

    assert_equal extended.id, replay_extension.id
    assert_equal BigDecimal("15"), extended.held_quantity
    assert_equal @now + 2.hours, extended.expires_at

    finalized = finalize(
      reservation: reservation,
      key: "finalize-lifecycle",
      actual_quantity: 12,
      at: @now + 10.minutes
    )
    replay = finalize(
      reservation: reservation,
      key: "finalize-lifecycle",
      actual_quantity: 12,
      at: @now + 10.minutes
    )

    assert_equal finalized.id, replay.id
    assert finalized.finalized?
    assert_equal BigDecimal("12"), finalized.consumed_quantity
    assert_equal BigDecimal("3"), finalized.released_quantity
    assert_equal BigDecimal("12"), finalized.finalized_usage_event.billed_quantity
    assert_equal 1, Usage::UsageEvent.count
    assert_equal %w[extend finalize], finalized.operations.order(:id).pluck(:operation_kind)
    summary = Usage::Public.summary(
      organization_id: @owner.organization.id,
      window_id: @window.id,
      at: @now + 12.minutes
    )
    assert_equal BigDecimal("12"), summary.used
    assert_equal BigDecimal("0"), summary.reserved
  end

  test "finalization atomically expands a conservative estimate only while snapshot capacity remains" do
    reservation = reserve(key: "reserve-underestimate", quantity: 5)
    finalized = finalize(
      reservation: reservation,
      key: "finalize-underestimate",
      actual_quantity: 7,
      at: @now + 5.minutes
    )

    assert_equal BigDecimal("7"), finalized.held_quantity
    assert_equal BigDecimal("7"), finalized.consumed_quantity
    assert_equal BigDecimal("0"), finalized.released_quantity
  end

  test "denied finalization expansion preserves the hold and creates no charge" do
    reserve(key: "reserve-most-capacity", quantity: 24_990)
    reservation = reserve(
      key: "reserve-underestimated-at-limit",
      quantity: 5,
      source_id: deterministic_uuid("scan", "underestimated-at-limit")
    )

    error = assert_raises(Usage::QuotaExceeded) do
      finalize(
        reservation: reservation,
        key: "finalize-over-capacity",
        actual_quantity: 11,
        at: @now + 5.minutes
      )
    end

    assert_equal BigDecimal("24995"), error.denial.reserved
    assert_equal BigDecimal("6"), error.denial.requested
    assert reservation.reload.held?
    assert_equal BigDecimal("5"), reservation.held_quantity
    assert_equal 0, Usage::UsageEvent.count
    assert_empty reservation.operations
  end

  test "zero-usage finalization releases the full hold without appending a charge" do
    reservation = reserve(key: "reserve-canceled-work", quantity: 8)
    finalized = finalize(
      reservation: reservation,
      key: "finalize-canceled-work",
      actual_quantity: 0,
      at: @now + 5.minutes
    )

    assert finalized.finalized?
    assert_equal BigDecimal("0"), finalized.consumed_quantity
    assert_equal BigDecimal("8"), finalized.released_quantity
    assert_nil finalized.finalized_usage_event_id
    assert_equal 0, Usage::UsageEvent.count
  end

  test "release is idempotent and never creates ledger usage" do
    reservation = reserve(key: "reserve-release", quantity: 8)
    released = Usage::Public.release_reservation(
      organization_id: @owner.organization.id,
      reservation_id: reservation.id,
      idempotency_key: "release-once",
      at: @now + 1.minute
    )
    replay = Usage::Public.release_reservation(
      organization_id: @owner.organization.id,
      reservation_id: reservation.id,
      idempotency_key: "release-once",
      at: @now + 2.minutes
    )

    assert_equal released.id, replay.id
    assert released.released?
    assert_equal BigDecimal("8"), released.released_quantity
    assert_equal 0, Usage::UsageEvent.count
    assert_equal 1, Usage::ReservationOperation.where(operation_kind: "release").count
  end

  test "unlimited is explicit and enterprise custom quota remains fail closed" do
    report_owner = create_organization_for(slug: "quota-unlimited-report")
    report_window = Usage::Public.resolve_window(
      organization_id: report_owner.organization.id,
      meter_key: "reports.generated",
      at: @now
    )
    unlimited = Usage::Public.reserve(
      window: report_window,
      idempotency_key: "reserve-unlimited-report",
      quantity: 1,
      source: usage_source(report_owner, type: "ReportRun"),
      expires_at: @now + 1.hour,
      at: @now
    )
    assert unlimited.unlimited?
    assert_nil unlimited.limit_quantity
    assert_equal "unlimited", unlimited.entitlement_state

    enterprise, = create_subscribed_usage_organization(
      plan_key: "enterprise",
      slug: "quota-enterprise-custom"
    )
    enterprise_window = usage_window_for(
      enterprise,
      at: @now,
      reference: "enterprise-custom-period"
    )
    error = assert_raises(Usage::Invalid) do
      Usage::Public.reserve(
        window: enterprise_window,
        idempotency_key: "reserve-enterprise-custom",
        quantity: 1,
        source: usage_source(enterprise),
        expires_at: @now + 1.hour,
        at: @now
      )
    end
    assert_equal "usage_quota_limit_unavailable", error.reason_code
  end

  test "an admitted reservation keeps its limit snapshot across a later plan override" do
    reservation = reserve(key: "reserve-before-plan-change", quantity: 10)
    Entitlements::Public.set_organization_override(
      organization_id: @owner.organization.id,
      entitlement_key: "crawl.credits_monthly",
      value: 5,
      starts_at: @now + 1.minute,
      reason: "Contract downgrade test",
      source: "contract",
      actor_membership: @owner.membership,
      authorization: @authorization
    )
    Current.reset

    extended = Usage::Public.extend_reservation(
      organization_id: @owner.organization.id,
      reservation_id: reservation.id,
      idempotency_key: "extend-old-snapshot",
      additional_quantity: 2,
      at: @now + 2.minutes
    )
    assert_equal BigDecimal("25000"), extended.limit_quantity
    assert_equal BigDecimal("12"), extended.held_quantity

    denial = assert_raises(Usage::QuotaExceeded) do
      reserve(
        key: "reserve-after-plan-change",
        quantity: 1,
        source_id: deterministic_uuid("scan", "after-plan-change"),
        at: @now + 2.minutes
      )
    end
    assert_equal BigDecimal("5"), denial.denial.limit
    assert_equal BigDecimal("12"), denial.denial.reserved
  end

  test "new usage window does not inherit reservations from the prior provider period" do
    reserve(key: "reserve-september", quantity: 24_999)
    october = usage_window_for(
      @owner,
      at: Time.utc(2026, 10, 4, 10),
      reference: "quota-period-october",
      starts_at: Time.utc(2026, 10, 1),
      ends_at: Time.utc(2026, 11, 1)
    )
    next_period = Usage::Public.reserve(
      window: october,
      idempotency_key: "reserve-october",
      quantity: 25_000,
      source: usage_source(@owner, id: deterministic_uuid("scan", "october")),
      expires_at: Time.utc(2026, 10, 4, 11),
      at: Time.utc(2026, 10, 4, 10)
    )

    assert_equal BigDecimal("25000"), next_period.held_quantity
  end

  test "cross tenant mutation is indistinguishable from a missing reservation" do
    reservation = reserve(key: "reserve-owned", quantity: 1)
    foreign = create_organization_for(slug: "quota-foreign")

    error = assert_raises(Usage::Invalid) do
      Usage::Public.release_reservation(
        organization_id: foreign.organization.id,
        reservation_id: reservation.id,
        idempotency_key: "release-cross-tenant",
        at: @now + 1.minute
      )
    end
    assert_equal "usage_reservation_not_found", error.reason_code
    assert reservation.reload.held?
  end

  private

  def usage_window_for(owner, at:, reference:, starts_at: Time.utc(2026, 9, 1),
    ends_at: Time.utc(2026, 10, 1))
    Usage::Public.resolve_window(
      organization_id: owner.organization.id,
      meter_key: "crawl.http_fetch",
      at: at,
      billing_period: Usage::BillingPeriod.new(
        starts_at: starts_at,
        ends_at: ends_at,
        time_zone_name: "UTC",
        reference: reference
      )
    )
  end

  def reserve(key:, quantity:, source_id: @source.id, at: @now)
    Usage::Public.reserve(
      window: @window,
      idempotency_key: key,
      quantity: quantity,
      source: usage_source(@owner, id: source_id),
      expires_at: @now + 1.hour,
      at: at
    )
  end

  def finalize(reservation:, key:, actual_quantity:, at:)
    Usage::Public.finalize_reservation(
      organization_id: @owner.organization.id,
      reservation_id: reservation.id,
      idempotency_key: key,
      actual_quantity: actual_quantity,
      occurred_at: at,
      at: at
    )
  end
end
