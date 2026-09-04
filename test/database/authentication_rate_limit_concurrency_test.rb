# frozen_string_literal: true

require "test_helper"

class AuthenticationRateLimitConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { Identity::AuthenticationRateLimitBucket.delete_all }
  teardown { Identity::AuthenticationRateLimitBucket.delete_all }

  test "PostgreSQL atomically admits only the configured concurrent attempts" do
    now = Time.current.change(usec: 0)
    policy = Identity::AuthenticationRateLimitPolicy.new(
      rules: {
        "session_action_session" => Identity::AuthenticationRateLimitPolicy::Rule.new(5, 1.minute)
      }
    )
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = 4.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          limiter = Identity::AuthenticationRateLimiter.new(policy: policy, clock: -> { now })
          ready << true
          start.pop
          3.times do
            limiter.consume!(scope: "session_action_session", key: "session-#{'a' * 40}")
            results << "allowed"
          rescue Identity::AuthenticationRateLimited => error
            results << "limited:#{error.retry_after}"
          rescue StandardError => error
            results << "unexpected:#{error.class.name}"
          end
        end
      end
    end
    4.times { ready.pop }
    4.times { start << true }
    threads.each(&:join)

    outcomes = 12.times.map { results.pop }
    assert_equal 5, outcomes.count("allowed")
    assert_equal 7, outcomes.count { |outcome| outcome.start_with?("limited:") }
    assert_empty outcomes.grep(/unexpected/)
    assert_equal 12, Identity::AuthenticationRateLimitBucket.sole.request_count
  end
end
