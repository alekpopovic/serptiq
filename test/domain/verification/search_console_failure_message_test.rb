# frozen_string_literal: true

require "test_helper"

class SearchConsoleFailureMessageTest < ActiveSupport::TestCase
  test "provides fixed provider-observation messages without reflecting input" do
    Verification::Challenge::FAILURE_CATEGORIES.grep(/\Aprovider_/).each do |category|
      assert_predicate Verification::SearchConsoleFailureMessage.for(category), :present?
    end

    fallback = Verification::SearchConsoleFailureMessage.for("provider_secret_attacker-value")
    assert_equal "Search Console did not confirm exact verified ownership.", fallback
    refute_includes fallback, "attacker-value"
  end
end
