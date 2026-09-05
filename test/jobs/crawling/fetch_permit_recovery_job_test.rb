# frozen_string_literal: true

require "test_helper"

class CrawlingFetchPermitRecoveryJobTest < ActiveJob::TestCase
  test "maintenance job delegates bounded stale permit recovery" do
    calls = 0
    original = Crawling::Public.method(:recover_stale_fetch_permits)
    Crawling::Public.define_singleton_method(:recover_stale_fetch_permits) { calls += 1 }
    begin
      Crawling::FetchPermitRecoveryJob.perform_now
    ensure
      Crawling::Public.define_singleton_method(:recover_stale_fetch_permits) do |**attributes|
        original.call(**attributes)
      end
    end

    assert_equal 1, calls
    assert_equal "maintenance", Crawling::FetchPermitRecoveryJob.new.queue_name
  end
end
