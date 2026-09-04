# frozen_string_literal: true

require "test_helper"

class WorkerHealthSnapshotTest < ActiveSupport::TestCase
  class FakeScope
    attr_reader :columns

    def initialize(rows)
      @rows = rows
    end

    def pluck(*columns)
      @columns = columns
      @rows
    end
  end

  test "provides a bounded internal heartbeat summary without process metadata" do
    now = Time.utc(2026, 9, 4, 3, 30, 0)
    scope = FakeScope.new([
      [ "Supervisor", now - 30 ],
      [ "Worker", now - 60 ],
      [ "Worker", now - 240 ]
    ])

    summary = Shared::WorkerHealthSnapshot.call(scope: scope, now: now, alive_threshold: 3.minutes)

    assert_equal :degraded, summary.status.to_sym
    assert_equal 3, summary.process_count
    assert_equal 2, summary.healthy_count
    assert_equal 1, summary.stale_count
    assert_equal({ supervisor: 1, dispatcher: 0, scheduler: 0, worker: 2 }, summary.kinds)
    assert_equal [ :kind, :last_heartbeat_at ], scope.columns
    refute_match(/hostname|pid|metadata|queue|job/, summary.to_h.to_s)
  end

  test "reports inactive when no worker processes are registered" do
    summary = Shared::WorkerHealthSnapshot.call(
      scope: FakeScope.new([]),
      now: Time.utc(2026, 9, 4),
      alive_threshold: 3.minutes
    )

    assert_equal "inactive", summary.status
    refute summary.healthy?
  end
end
