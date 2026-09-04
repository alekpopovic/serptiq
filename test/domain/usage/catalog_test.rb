# frozen_string_literal: true

require "test_helper"

class UsageCatalogTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE usage_meter_definitions, audit_events CASCADE"
    )
    Plans::Public.sync_catalog
    Entitlements::Public.sync_catalog
  end

  test "validates the seven governed meters and plan-owned weighted credit values" do
    catalog = Usage::Public.validate_catalog

    assert_equal 7, catalog.meters.length
    assert_equal Usage::Catalog::EXPECTED_KEYS, catalog.meters.map(&:key)
    assert_equal BigDecimal("10"), catalog.meters.find { |meter| meter.key == "crawl.rendered_page" }.rates.first.weight
    assert_equal "utc_calendar_month", catalog.meters.last.window_policy
  end

  test "synchronizes definitions and effective rates once and audits the material change" do
    first = Usage::Public.sync_catalog
    identities = Usage::MeterDefinition.order(:key).pluck(:key, :id)
    second = Usage::Public.sync_catalog

    assert_equal 14, first.change_count
    assert_equal 7, first.meter_count
    assert_equal 7, first.rate_count
    assert_equal 0, second.change_count
    assert_equal identities, Usage::MeterDefinition.order(:key).pluck(:key, :id)
    assert_equal 1, Auditing::AuditEvent.where(action: "usage.catalog_synchronized").count
  end

  test "dry run has no database or audit side effects" do
    result = Usage::Public.sync_catalog(dry_run: true)

    assert_predicate result, :dry_run?
    assert_equal 14, result.change_count
    assert_equal 0, Usage::MeterDefinition.count
    refute Auditing::AuditEvent.exists?(action: "usage.catalog_synchronized")
  end

  test "model and database prevent rewriting meter and rate history" do
    Usage::Public.sync_catalog
    meter = Usage::MeterDefinition.find_by!(key: "crawl.http_fetch")
    rate = meter.rates.first

    assert_raises(ActiveRecord::ReadOnlyRecord) { meter.update!(unit: "pages") }
    assert_raises(ActiveRecord::StatementInvalid) do
      Usage::MeterRate.transaction(requires_new: true) do
        Usage::MeterRate.where(id: rate.id).update_all(weight: 99)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Usage::MeterDefinition.transaction(requires_new: true) do
        Usage::MeterDefinition.where(id: meter.id).delete_all
      end
    end
  end
end
