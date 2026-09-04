# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require Rails.root.join("script/support/architecture_boundary_checker")

class ArchitectureBoundaryCheckerTest < ActiveSupport::TestCase
  setup do
    @temporary_root = Pathname(Dir.mktmpdir("searchops-boundaries"))
  end

  teardown do
    FileUtils.remove_entry(@temporary_root)
  end

  test "allows a dependency through its public API" do
    write_domain_file("projects/operation.rb", "Projects::Operation.call(Tenancy::Public::OrganizationId)\n")

    assert_empty checker.check
  end

  test "rejects a dependency that is absent from the allowlist" do
    write_domain_file("identity/session.rb", "Identity::Session.new(Billing::Public::Customer)\n")

    violation = checker.check.sole

    assert_equal "identity", violation.source
    assert_equal "billing", violation.target
    assert_equal "Billing::Public::Customer", violation.constant
    assert_equal "dependency is not allowed", violation.reason
  end

  test "rejects direct access to an allowed module internal constant" do
    write_domain_file("projects/operation.rb", "Projects::Operation.call(Tenancy::Membership)\n")

    violation = checker.check.sole

    assert_equal "Tenancy::Membership", violation.constant
    assert_equal "cross-module references must use Tenancy::Public", violation.reason
  end

  private

  def checker
    Searchops::Architecture::BoundaryChecker.new(
      root: @temporary_root,
      config_path: Rails.root.join("config/architecture.yml")
    )
  end

  def write_domain_file(relative_path, contents)
    path = @temporary_root.join("app/domains", relative_path)
    path.dirname.mkpath
    path.write(contents)
  end
end
