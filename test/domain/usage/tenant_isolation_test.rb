# frozen_string_literal: true

require "test_helper"

class UsageTenantIsolationTest < ActiveSupport::TestCase
  setup do
    sync_usage_catalog
    @operator = create_identity_user(display_name: "Usage Adjustment Operator")
    @owned, @authorization = create_subscribed_usage_organization(
      slug: "usage-adjustment-owned", user: @operator
    )
    @foreign, = create_subscribed_usage_organization(slug: "usage-adjustment-foreign")
    @window = resolve_usage_window(@owned)
  end

  test "source aggregate must declare the same tenant as the window" do
    foreign_source = usage_source(@foreign)

    error = assert_raises(Usage::Invalid) do
      Usage::Public.record(
        window: @window,
        idempotency_key: "cross-tenant-source",
        quantity: 1,
        source: foreign_source,
        occurred_at: Time.utc(2026, 1, 15)
      )
    end
    assert_equal "usage_event_context_invalid", error.reason_code
    assert_equal 0, Usage::UsageEvent.count
  end

  test "database composite constraints reject a foreign window or source tenant" do
    foreign_window = resolve_usage_window(@foreign, billing_period: provider_usage_period(reference: "foreign-period"))
    rate = Usage::MeterRate.effective_at(Time.utc(2026, 1, 15)).find_by!(
      usage_meter_definition_id: @window.usage_meter_definition_id
    )
    attributes = raw_event_attributes(rate).merge(
      usage_window_id: foreign_window.id,
      source_organization_id: @foreign.organization.id
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      Usage::UsageEvent.transaction(requires_new: true) do
        Usage::UsageEvent.insert!(attributes)
      end
    end
  end

  test "manual adjustment requires platform authority bound to an active target membership and emits audit" do
    event = Usage::Public.record_manual_adjustment(
      window: @window,
      idempotency_key: "manual-credit-1",
      quantity: -5,
      source: usage_source(@owned, type: "Subscription"),
      actor_membership: @owned.membership,
      authorization: @authorization,
      reason_code: "support_credit",
      occurred_at: Time.utc(2026, 1, 20)
    )

    assert_equal "manual_adjustment", event.event_kind
    audit = Auditing::AuditEvent.find_by!(
      action: "usage.manual_adjusted", target_id: @window.id
    )
    assert_equal @owned.membership.id, audit.actor_membership_id
    assert_equal "crawl.http_fetch", audit.metadata.fetch("meter")
    assert_equal "support_credit", audit.metadata.fetch("reason_code")

    assert_raises(Usage::AccessDenied) do
      Usage::Public.record_manual_adjustment(
        window: @window,
        idempotency_key: "manual-credit-cross-tenant",
        quantity: -1,
        source: usage_source(@owned),
        actor_membership: @foreign.membership,
        authorization: @authorization,
        reason_code: "support_credit"
      )
    end
  end

  test "summary cannot read another tenant window by identifier" do
    assert_raises(Usage::Invalid) do
      Usage::Public.summary(
        organization_id: @foreign.organization.id,
        window_id: @window.id
      )
    end
  end

  private

  def raw_event_attributes(rate)
    {
      organization_id: @owned.organization.id,
      usage_window_id: @window.id,
      usage_meter_definition_id: @window.usage_meter_definition_id,
      usage_meter_rate_id: rate.id,
      idempotency_key_digest: Digest::SHA256.hexdigest("raw-cross-tenant"),
      request_checksum: "a" * 64,
      event_kind: "usage",
      quantity: 1,
      applied_weight: rate.weight,
      billed_quantity: rate.weight,
      source_type: "Scan",
      source_id: SecureRandom.uuid,
      metadata: {},
      occurred_at: Time.utc(2026, 1, 15),
      recorded_at: Time.utc(2026, 1, 15)
    }
  end
end
