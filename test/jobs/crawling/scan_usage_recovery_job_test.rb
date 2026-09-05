# frozen_string_literal: true

require "test_helper"

class CrawlingScanUsageRecoveryJobTest < ActiveJob::TestCase
  test "maintenance job delegates bounded terminal usage recovery" do
    calls = 0
    original = Crawling::Public.method(:recover_terminal_scan_usage)
    Crawling::Public.define_singleton_method(:recover_terminal_scan_usage) { calls += 1 }
    begin
      Crawling::ScanUsageRecoveryJob.perform_now
    ensure
      Crawling::Public.define_singleton_method(:recover_terminal_scan_usage) do |**attributes|
        original.call(**attributes)
      end
    end

    assert_equal 1, calls
    assert_equal "maintenance", Crawling::ScanUsageRecoveryJob.new.queue_name
  end
end
