# frozen_string_literal: true

require "test_helper"

class AuthorizationCatalogTest < ActiveSupport::TestCase
  test "loads the governed catalog with complete typed metadata and a stable checksum" do
    first = Authorization::Catalog.load
    second = Authorization::Catalog.load

    assert_equal 1, first.schema_version
    assert_equal 57, first.permissions.length
    assert_equal 8, first.roles.length
    assert_equal first.checksum, second.checksum
    assert_match(/\A[0-9a-f]{64}\z/, first.checksum)
    assert first.permissions.all? { |permission| permission.description.present? }
    assert first.permissions.all? { |permission| Authorization::Permission::SCOPES.include?(permission.scope) }
    assert_equal first.permissions.map(&:key).sort,
      first.roles.find { |role| role.key == "owner" }.permission_keys.sort
  end

  test "rejects duplicate keys duplicate grants unknown grants and missing required metadata" do
    document = load_document
    document.fetch("permissions")[1]["key"] = document.fetch("permissions").first.fetch("key")
    document.fetch("permissions")[2].delete("description")
    document.fetch("permissions")[3].delete("category")
    document.fetch("permissions")[4].delete("scope")
    document.fetch("system_roles").first.fetch("permissions") << "unknown.permission"
    document.fetch("system_roles")[1].fetch("permissions") <<
      document.fetch("system_roles")[1].fetch("permissions").first

    error = assert_raises(Authorization::CatalogInvalid) { load_temporary_catalog(document) }
    assert error.issues.any? { |issue| issue.include?("duplicate permission key") }
    assert error.issues.any? { |issue| issue.include?("lacks description") }
    assert error.issues.any? { |issue| issue.include?("lacks category") }
    assert error.issues.any? { |issue| issue.include?("lacks scope") }
    assert error.issues.any? { |issue| issue.include?("unknown permissions") }
    assert error.issues.any? { |issue| issue.include?("repeats permission") }
  end

  test "generated grants exactly match the documented permission matrix" do
    catalog = Authorization::Catalog.load
    documented = documented_grants

    assert_equal catalog.permissions.map(&:key).sort, documented.keys.sort
    catalog.roles.each do |role|
      grants = documented.filter_map { |permission, roles| permission if roles.include?(role.name) }.sort
      assert_equal role.permission_keys.sort, grants, "grant mismatch for #{role.name}"
    end
  end

  test "development report includes checksum scope risk and all system roles" do
    report = Authorization::CatalogReport.new.call

    assert_includes report, "sha256:#{Authorization::Catalog.load.checksum}"
    assert_includes report, "Permission"
    assert_includes report, "organization.read"
    Authorization::Catalog::EXPECTED_ROLES.each_value { |name| assert_includes report, name }
  end

  private

  def load_document
    YAML.safe_load_file(Authorization::Catalog::DEFAULT_PATH, aliases: false)
  end

  def load_temporary_catalog(document)
    Dir.mktmpdir("authorization-catalog") do |directory|
      path = Pathname(directory).join("permissions.yml")
      path.write(YAML.dump(document))
      return Authorization::Catalog.load(path: path)
    end
  end

  def documented_grants
    roles = Authorization::Catalog::EXPECTED_ROLES.values
    docs = Rails.root.join("docs/04_RBAC_PERMISSION_MATRIX.md").read
    docs.lines.filter_map do |line|
      next unless line.start_with?("| `")

      columns = line.split("|")[1...-1].map(&:strip)
      next unless columns.length == roles.length + 1

      permission = columns.shift.delete("`")
      [ permission, roles.zip(columns).filter_map { |role, mark| role if mark == "✓" } ]
    end.to_h
  end
end
