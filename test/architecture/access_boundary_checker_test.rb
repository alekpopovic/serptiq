# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require Rails.root.join("script/support/access_boundary_checker")

class AccessBoundaryCheckerTest < ActiveSupport::TestCase
  setup do
    @temporary_root = Pathname(Dir.mktmpdir("searchops-access-boundary"))
  end

  teardown do
    FileUtils.remove_entry(@temporary_root)
  end

  test "rejects commercial plan-name branching in feature modules" do
    write("app/domains/crawling/start_scan.rb", 'allowed = plan_key == "growth"')

    violation = checker.check.sole

    assert_equal "app/domains/crawling/start_scan.rb", violation.path
    assert_match(/entitlement keys/, violation.reason)
  end

  test "rejects direct quota calls and model writes outside the boundary" do
    write("app/controllers/scans_controller.rb", "Usage::Public.reserve(**attributes)\n")
    write("app/jobs/crawling/run_job.rb", "Usage::QuotaReservation.update_all(state: 'released')\n")

    violations = checker.check

    assert_equal 2, violations.size
    assert violations.all? { |violation| violation.reason.include?("quota mutations") }
  end

  test "allows the unified boundary and the usage owner to mutate quota" do
    write("app/domains/authorization/access_boundary.rb", "Usage::Public.reserve(**attributes)\n")
    write("app/domains/usage/release.rb", "Usage::QuotaReservation.update!(state: 'released')\n")

    assert_empty checker.check
  end

  test "rejects billing provider classes and identifiers in core access code" do
    write("app/domains/authorization/provider_gate.rb", "LemonSqueezy::Variant.find(provider_variant_id)\n")

    violation = checker.check.sole

    assert_match(/provider classes/, violation.reason)
  end

  private

  def checker
    Searchops::Architecture::AccessBoundaryChecker.new(root: @temporary_root)
  end

  def write(relative_path, contents)
    path = @temporary_root.join(relative_path)
    path.dirname.mkpath
    path.write(contents)
  end
end
