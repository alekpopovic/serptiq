# frozen_string_literal: true

require "test_helper"

class AuthorizationCatalogSyncTest < ActiveSupport::TestCase
  test "sync is idempotent and retains stable IDs while recording the revision" do
    first = Authorization::CatalogSync.new.call
    permission_ids = Authorization::Permission.order(:key).pluck(:key, :id)
    role_ids = Authorization::Role.where(system: true).order(:key).pluck(:key, :id)
    counts = [
      Authorization::Permission.count,
      Authorization::Role.where(system: true).count,
      Authorization::RolePermission.count,
      Authorization::CatalogRevision.count
    ]

    second = Authorization::CatalogSync.new.call

    assert_equal 57, first.permission_count
    assert_equal 8, first.role_count
    assert_equal 229, first.grant_count
    assert_equal 0, second.change_count
    assert_equal permission_ids, Authorization::Permission.order(:key).pluck(:key, :id)
    assert_equal role_ids, Authorization::Role.where(system: true).order(:key).pluck(:key, :id)
    assert_equal counts, [
      Authorization::Permission.count,
      Authorization::Role.where(system: true).count,
      Authorization::RolePermission.count,
      Authorization::CatalogRevision.count
    ]
    revision = Authorization::CatalogRevision.find_by!(checksum: second.checksum)
    assert_equal "config_blueprints/permissions.yml", revision.source_path
  end

  test "metadata updates are audited as a new checksum without renaming stable keys" do
    Authorization::CatalogSync.new.call
    original = Authorization::Permission.find_by!(key: "organization.read")
    original_id = original.id
    document = load_document
    document.fetch("permissions").find { |row| row.fetch("key") == "organization.read" }["description"] =
      "View organization profile, locale and settings"
    catalog = temporary_catalog(document)

    result = Authorization::CatalogSync.new(catalog: catalog).call

    updated = Authorization::Permission.find_by!(key: "organization.read")
    assert_equal original_id, updated.id
    assert_equal "View organization profile, locale and settings", updated.description
    assert_equal catalog.checksum, updated.catalog_checksum
    assert Authorization::CatalogRevision.exists?(checksum: result.checksum)
  end

  test "a catalog rename is rejected and the existing in-use key and grants remain" do
    Authorization::CatalogSync.new.call
    document = load_document
    document.fetch("permissions").find { |row| row.fetch("key") == "organization.read" }["key"] =
      "organization.view"
    document.fetch("system_roles").each do |role|
      role.fetch("permissions").map! { |key| key == "organization.read" ? "organization.view" : key }
    end
    catalog = temporary_catalog(document)
    before_grants = Authorization::RolePermission.count

    error = assert_raises(Authorization::CatalogRemovalDenied) do
      Authorization::CatalogSync.new(catalog: catalog).call
    end
    assert_equal [ "organization.read" ], error.keys
    assert Authorization::Permission.exists?(key: "organization.read")
    refute Authorization::Permission.exists?(key: "organization.view")
    assert_equal before_grants, Authorization::RolePermission.count
  end

  private

  def load_document
    YAML.safe_load_file(Authorization::Catalog::DEFAULT_PATH, aliases: false)
  end

  def temporary_catalog(document)
    directory = Pathname(Dir.mktmpdir("authorization-sync"))
    path = directory.join("permissions.yml")
    path.write(YAML.dump(document))
    Authorization::Catalog.load(path: path)
  ensure
    FileUtils.remove_entry(directory) if directory&.exist?
  end
end
