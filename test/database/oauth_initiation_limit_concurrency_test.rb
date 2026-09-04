# frozen_string_literal: true

require "test_helper"

class OauthInitiationLimitConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { Identity::OauthTransaction.delete_all }
  teardown { Identity::OauthTransaction.delete_all }

  test "a PostgreSQL advisory lock atomically caps concurrent outstanding starts" do
    now = Time.current.change(usec: 0)
    policy = build_oauth_initiation_policy(max_open_per_ip: 1)
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = 2.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          secrets = deterministic_oauth_secrets(index + 1)
          result = Identity::OauthInitiationLimiter.new(policy: policy).within_limit(
            initiator_digest: "a" * 64,
            link_session: nil,
            now: now
          ) do
            Identity::OauthTransaction.create_protected!(
              provider: "google",
              state: secrets.state,
              nonce: secrets.nonce,
              pkce_verifier: secrets.pkce_verifier,
              return_to: "/dashboard",
              expires_at: now + 10.minutes,
              initiator_digest: "a" * 64
            )
          end
          results << result.id
        rescue Identity::OauthInitiationLimited => error
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
    assert_equal 1, outcomes.count("oauth_start_ip_outstanding_limited")
    assert_equal 1, Identity::OauthTransaction.count
    assert_equal 1, outcomes.count { |outcome| Identity::OauthTransaction.exists?(outcome) }
  end
end
