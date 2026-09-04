# frozen_string_literal: true

require "test_helper"

class UsageWindowResolverTest < ActiveSupport::TestCase
  setup { sync_usage_catalog }

  test "UTC calendar months ignore organization timezone and roll over at the exact UTC boundary" do
    owner = create_organization_for(slug: "usage-utc-window")
    owner.organization.update!(time_zone: "Pacific Time (US & Canada)")
    before_boundary = Time.utc(2026, 3, 31, 23, 59, 59, 999_999)
    at_boundary = Time.utc(2026, 4, 1)

    march = Usage::Public.resolve_window(
      organization_id: owner.organization.id, meter_key: "reports.generated", at: before_boundary
    )
    april = Usage::Public.resolve_window(
      organization_id: owner.organization.id, meter_key: "reports.generated", at: at_boundary
    )

    assert_equal [ Time.utc(2026, 3, 1), Time.utc(2026, 4, 1), "UTC" ],
      [ march.starts_at, march.ends_at, march.time_zone_name ]
    assert_equal [ Time.utc(2026, 4, 1), Time.utc(2026, 5, 1) ], [ april.starts_at, april.ends_at ]
    assert_not_equal march.id, april.id
  end

  test "provider period retains exact instants timezone policy and subscription snapshot across DST" do
    owner, = create_subscribed_usage_organization(slug: "usage-provider-window")
    zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    period = Usage::BillingPeriod.new(
      starts_at: zone.local(2026, 3, 1),
      ends_at: zone.local(2026, 4, 1),
      time_zone_name: zone.name,
      reference: "provider-period-dst"
    )
    window = resolve_usage_window(
      owner,
      at: zone.local(2026, 3, 15),
      billing_period: period
    )

    assert_equal period.starts_at, window.starts_at
    assert_equal period.ends_at, window.ends_at
    assert_equal zone.name, window.time_zone_name
    assert_equal "provider_billing_period", window.window_policy
    assert_equal Digest::SHA256.hexdigest("provider-period-dst"), window.period_reference_digest
    refute_includes window.attributes.to_json, "provider-period-dst"
    assert window.subscription_id
    assert window.plan_version_id
    assert_equal 0, window.subscription_revision
  end

  test "provider meters fail closed without an explicit period or active subscription context" do
    owner = create_organization_for(slug: "usage-missing-period")

    missing_period = assert_raises(Usage::Invalid) do
      Usage::Public.resolve_window(
        organization_id: owner.organization.id,
        meter_key: "crawl.http_fetch",
        at: Time.utc(2026, 1, 15)
      )
    end
    assert_equal "usage_billing_period_required", missing_period.reason_code

    missing_context = assert_raises(Usage::Invalid) do
      resolve_usage_window(owner)
    end
    assert_equal "usage_subscription_context_required", missing_context.reason_code
  end

  test "windows are idempotent immutable and cannot overlap" do
    owner = create_organization_for(slug: "usage-window-guards")
    first = Usage::Public.resolve_window(
      organization_id: owner.organization.id, meter_key: "reports.generated", at: Time.utc(2026, 1, 20)
    )
    duplicate = Usage::Public.resolve_window(
      organization_id: owner.organization.id, meter_key: "reports.generated", at: Time.utc(2026, 1, 25)
    )
    assert_equal first.id, duplicate.id
    assert_raises(ActiveRecord::ReadOnlyRecord) { first.update!(ends_at: first.ends_at + 1.day) }

    assert_raises(ActiveRecord::StatementInvalid) do
      Usage::UsageWindow.transaction(requires_new: true) do
        Usage::UsageWindow.insert! first.attributes.except("id").merge(
          "id" => SecureRandom.uuid,
          "starts_at" => first.starts_at + 1.day,
          "ends_at" => first.ends_at + 1.day
        )
      end
    end
  end
end
