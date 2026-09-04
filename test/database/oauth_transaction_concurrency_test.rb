# frozen_string_literal: true

require "test_helper"

class OauthTransactionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { Identity::OauthTransaction.delete_all }
  teardown { Identity::OauthTransaction.delete_all }

  test "a PostgreSQL row lock permits exactly one consumer" do
    now = Time.current.change(usec: 0)
    material = create_oauth_transaction(expires_at: now + 10.minutes)
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          result = Identity::Public.consume_oauth_transaction!(
            state: material.fetch(:state),
            clock: -> { now }
          )
          results << result.id
        rescue Identity::ConsumedOauthTransaction => error
          results << error.reason_code
        rescue StandardError => error
          results << "unexpected:#{error.class.name}"
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)

    outcomes = 2.times.map { results.pop }
    assert_equal 1, outcomes.count(material.fetch(:transaction).id)
    assert_equal 1, outcomes.count("oauth_transaction_consumed")
    assert_equal 2, material.fetch(:transaction).reload.attempt_count
    assert_not_nil material.fetch(:transaction).consumed_at
  end
end
