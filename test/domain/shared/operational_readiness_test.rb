# frozen_string_literal: true

require "test_helper"

class OperationalReadinessTest < ActiveSupport::TestCase
  FakeResult = Data.define(:ready, :latency_ms, :error) do
    def ready?
      ready
    end
  end

  test "checks only the bounded PostgreSQL dependencies for each process role" do
    calls = []
    checker = Object.new
    checker.define_singleton_method(:call) do |database:, timeout_ms:|
      calls << [ database, timeout_ms ]
      FakeResult.new(true, 1.25, nil)
    end

    result = Shared::OperationalReadiness.call(role: :web, checker: checker, timeout_ms: 250)

    assert result.ready?
    assert_equal [ [ :primary, 250 ], [ :queue, 250 ] ], calls
    assert_equal({ status: "ready", checks: { postgresql: "ok" } }, result.public_payload)
  end

  test "scheduler checks only queue PostgreSQL and never broad provider health" do
    calls = []
    checker = Object.new
    checker.define_singleton_method(:call) do |database:, timeout_ms:|
      calls << [ database, timeout_ms ]
      FakeResult.new(true, 1.0, nil)
    end

    Shared::OperationalReadiness.call(role: :scheduler, checker: checker, timeout_ms: 100)

    assert_equal [ [ :queue, 100 ] ], calls
  end

  test "fails closed with a stable public payload when a dependency raises" do
    checker = Object.new
    checker.define_singleton_method(:call) do |**_arguments|
      raise PG::ConnectionBad, "postgresql://user:password@internal/database"
    end

    result = Shared::OperationalReadiness.call(role: :worker_crawl, checker: checker, timeout_ms: 100)

    refute result.ready?
    assert_equal({ status: "not_ready", checks: { postgresql: "unavailable" } }, result.public_payload)
    assert_equal [ "unavailable", "unavailable" ], result.checks.map(&:reason)
    refute_match(/password|internal|database/, result.public_payload.to_s)
  end

  test "rejects unknown process roles" do
    assert_raises(ArgumentError) do
      Shared::OperationalReadiness.call(role: :customer_supplied_role)
    end
  end
end
