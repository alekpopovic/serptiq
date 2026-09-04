# frozen_string_literal: true

require "test_helper"

class IdentitySafeReturnPathTest < ActiveSupport::TestCase
  test "accepts only allowlisted local application paths" do
    assert_equal "/dashboard", Identity::SafeReturnPath.call("/dashboard")
    assert_equal "/dashboard/scans", Identity::SafeReturnPath.call("/dashboard/scans")
    assert_equal "/dashboard", Identity::SafeReturnPath.call("/dashboard?tab=recent#results")
  end

  test "falls back for external protocol-relative unlisted and malformed values" do
    unsafe_values = [
      "https://attacker.example/dashboard",
      "//attacker.example/dashboard",
      "javascript:alert(1)",
      "/admin",
      "/dashboard\\attacker",
      "/dashboard/%2e%2e/admin",
      "http://[invalid"
    ]

    unsafe_values.each do |value|
      assert_equal "/dashboard", Identity::SafeReturnPath.call(value), value
    end
  end
end
