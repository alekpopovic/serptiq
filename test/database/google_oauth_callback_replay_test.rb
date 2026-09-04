# frozen_string_literal: true

require "test_helper"

class GoogleOauthCallbackReplayTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { delete_identity_records }
  teardown { delete_identity_records }

  test "one state and code permit at most one account and local session transition" do
    now = Time.current.change(usec: 0)
    material = create_oauth_transaction(expires_at: now + 10.minutes)
    identity = Identity::NormalizedIdentity.new(
      provider: "google",
      subject: "concurrent-google-subject",
      email: "concurrent@example.test",
      email_verified: true
    )
    exchange = Identity::CallbackExchange.new(
      identity: identity,
      oidc_claims: Identity::OidcClaims.new(
        issuer: "https://accounts.google.com",
        subject: identity.subject,
        audiences: [ "synthetic-google-client-id" ],
        authorized_party: "synthetic-google-client-id",
        issued_at: now,
        expires_at: now + 1.hour,
        nonce: material.fetch(:nonce),
        key_id: "synthetic-key",
        algorithm: "RS256"
      )
    )
    adapter = TestSupport::GoogleCallbackAdapterFake.new(
      configuration: build_google_configuration,
      result: exchange
    )
    callback = Identity::GoogleCallbackParameters.new(
      state: material.fetch(:state), code: "concurrent-authorization-code", error: nil
    )
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          completion = Identity::GoogleCallbackCompleter.new(adapter: adapter, clock: -> { now })
            .call(callback: callback, current_session: nil)
          Identity::Public.issue_session(user: completion.user, clock: -> { now })
          results << "succeeded"
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
    assert_equal 1, outcomes.count("succeeded")
    assert_equal 1, outcomes.count("oauth_transaction_consumed")
    assert_equal 1, Identity::User.count
    assert_equal 1, Identity::ProviderIdentity.count
    assert_equal 1, Identity::Session.count
    assert_equal 1, adapter.calls.length
    assert_equal 2, material.fetch(:transaction).reload.attempt_count
  end

  private

  def delete_identity_records
    Identity::OauthTransaction.delete_all
    Identity::Session.delete_all
    Identity::ProviderIdentity.delete_all
    Identity::User.delete_all
  end
end
