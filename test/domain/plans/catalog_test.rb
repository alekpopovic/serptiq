# frozen_string_literal: true

require "test_helper"

class PlansCatalogTest < ActiveSupport::TestCase
  test "governed catalog contains exactly five stable products and complete entitlement snapshots" do
    catalog = Plans::Public.validate_catalog

    assert_equal 1, catalog.schema_version
    assert_equal %w[free starter growth agency enterprise], catalog.definitions.map(&:key)
    assert_equal [ 1, 2, 3, 4, 5 ], catalog.definitions.map(&:display_order)
    assert catalog.definitions.all? { |definition| definition.entitlements.length == 47 }
    assert catalog.definitions.first.entitlements.frozen?
    assert_equal "custom", catalog.definitions.last.pricing_kind
    assert_nil catalog.definitions.last.monthly_price_cents
  end

  test "unknown provider fields and incomplete products fail closed" do
    document = source_document
    document.fetch("plans").first["provider_variant_id"] = "must-not-enter-core"
    document.fetch("plans").pop

    error = assert_raises(Plans::CatalogInvalid) do
      Plans::Public.validate_catalog(path: temporary_catalog(document))
    end

    assert_includes error.issues, "plan keys must be free, starter, growth, agency, enterprise"
    assert error.issues.any? { |issue| issue.include?("unknown fields") }
  end

  test "missing governed root keys and invalid credit weights are rejected" do
    document = source_document
    document.delete("generated_for")
    document.fetch("credit_weights")["crawl.http_fetch"] = 0

    error = assert_raises(Plans::CatalogInvalid) do
      Plans::Public.validate_catalog(path: temporary_catalog(document))
    end

    assert_includes error.issues, "catalog root must contain exactly the governed keys"
    assert_includes error.issues, "credit weights must be positive integers with stable keys"
  end

  test "nested and unbounded entitlement payloads are rejected" do
    document = source_document
    document.fetch("plans").first.fetch("entitlements")["projects.max"] = { "unsafe" => true }

    error = assert_raises(Plans::CatalogInvalid) do
      Plans::Public.validate_catalog(path: temporary_catalog(document))
    end

    assert error.issues.any? { |issue| issue.include?("invalid entitlement values") }
  end

  private

  def source_document
    YAML.safe_load_file(Plans::Catalog::DEFAULT_PATH, permitted_classes: [ Date ], aliases: false)
  end

  def temporary_catalog(document)
    directory = Pathname(Dir.mktmpdir("plans-catalog"))
    path = directory.join("plans.yml")
    path.write(YAML.dump(document))
    @temporary_catalog_directories ||= []
    @temporary_catalog_directories << directory
    path
  end

  teardown do
    Array(@temporary_catalog_directories).each do |directory|
      FileUtils.remove_entry(directory) if directory.exist?
    end
  end
end
