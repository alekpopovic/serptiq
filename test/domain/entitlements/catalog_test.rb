# frozen_string_literal: true

require "test_helper"

class EntitlementsCatalogTest < ActiveSupport::TestCase
  test "governed definitions cover every exact plan entitlement with typed metadata" do
    catalog = Entitlements::Public.validate_catalog

    assert_equal 47, catalog.definitions.length
    assert_equal catalog.definitions.map(&:key), catalog.plan_definitions.first.entitlements.keys
    assert_equal %w[boolean enum integer], catalog.definitions.map(&:value_type).uniq.sort
    assert catalog.definitions.all? { |definition| definition.customer_description.present? }
    assert catalog.definitions.select(&:security_sensitive).all? do |definition|
      normalized = Entitlements::TypedValue.new.normalize(
        definition: definition, raw: definition.system_default, custom_allowed: false
      )
      !Entitlements::TypedValue.new.enabled?(definition: definition, value: normalized.value)
    end
  end

  test "missing and loosely typed plan values fail catalog validation" do
    missing_path = plans_catalog_with do |document|
      document.fetch("plans").first.fetch("entitlements").delete("reports.html")
    end
    wrong_type_path = plans_catalog_with do |document|
      document.fetch("plans")[1].fetch("entitlements")["projects.max"] = "3"
    end

    missing = assert_raises(Entitlements::CatalogInvalid) do
      Entitlements::Public.validate_catalog(plans_path: missing_path)
    end
    wrong = assert_raises(Entitlements::CatalogInvalid) do
      Entitlements::Public.validate_catalog(plans_path: wrong_type_path)
    end

    assert missing.issues.any? { |issue| issue.include?("incomplete entitlements") }
    assert wrong.issues.any? { |issue| issue.include?("entitlement projects.max is invalid") }
  end

  private

  def plans_catalog_with
    document = YAML.safe_load_file(Entitlements::Catalog::DEFAULT_PLANS_PATH, permitted_classes: [ Date ], aliases: false)
    yield document
    directory = Pathname(Dir.mktmpdir("entitlement-plan-catalog"))
    path = directory.join("plans.yml")
    path.write(YAML.dump(document))
    @temporary_directories ||= []
    @temporary_directories << directory
    path
  end

  teardown do
    Array(@temporary_directories).each do |directory|
      FileUtils.remove_entry(directory) if directory.exist?
    end
  end
end
