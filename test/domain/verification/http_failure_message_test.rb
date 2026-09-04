# frozen_string_literal: true

require "test_helper"

module Verification
  class HttpFailureMessageTest < ActiveSupport::TestCase
    test "describes bounded HTTP failures without reflecting unsafe evidence" do
      Challenge::FAILURE_CATEGORIES.grep(/\A(?:http_|duplicate_meta)/).each do |category|
        message = HttpFailureMessage.for(category)

        assert_predicate message, :present?
        refute_includes message, "http://"
      end
    end

    test "uses a stable generic message for an unknown category" do
      assert_equal(
        "Proof was not observed yet. Check the exact instructions before retrying.",
        HttpFailureMessage.for("attacker-controlled-value")
      )
    end
  end
end
