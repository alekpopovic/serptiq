# frozen_string_literal: true

require "test_helper"
require Rails.root.join("script/support/authorization_coverage_checker")

class AuthorizationCoverageCheckerTest < ActiveSupport::TestCase
  test "all tenant controllers jobs and mapped operations have governed policies" do
    issues = Searchops::Authorization::CoverageChecker.new(
      root: Rails.root,
      inventory_path: Rails.root.join("config/authorization_inventory.yml")
    ).check

    assert_empty issues, issues.join("\n")
  end
end
