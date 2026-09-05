# frozen_string_literal: true

require "test_helper"
require "English"

class CrawlerEgressPolicyTest < ActiveSupport::TestCase
  test "machine-readable infrastructure policy stays synchronized with the application boundary" do
    output = IO.popen(
      [ RbConfig.ruby, Rails.root.join("script/validate_crawler_egress_policy.rb").to_s ],
      err: [ :child, :out ],
      &:read
    )

    assert $CHILD_STATUS.success?, output
    assert_equal "Crawler egress policy: passed\n", output
  end
end
