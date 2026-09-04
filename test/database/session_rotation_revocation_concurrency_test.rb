# frozen_string_literal: true

require "test_helper"

class SessionRotationRevocationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { delete_identity_records }
  teardown { delete_identity_records }

  test "simultaneous rotation and revocation cannot leave the old token reusable" do
    now = Time.current.change(usec: 0)
    original = issue_identity_session(at: now - 1.minute)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    operations = [
      -> { Identity::Public.rotate_session!(session: original.session, clock: -> { now }) },
      -> { Identity::Public.revoke_session(session: original.session, reason: "administrative", clock: -> { now }) }
    ]

    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          result = operation.call
          results << (result.is_a?(Identity::IssuedSession) ? "rotated" : "revoked:#{result}")
        rescue Identity::RevokedSession => error
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
    assert_not_nil original.session.reload.revoked_at
    assert_operator Identity::Session.where(rotated_from_id: original.session.id).count, :<=, 1
    assert outcomes.none? { |outcome| outcome.start_with?("unexpected:") }, outcomes.inspect
    assert_raises(Identity::RevokedSession) do
      Identity::Public.authenticate_session!(token: original.token, clock: -> { now + 1.second })
    end
  end

  private

  def delete_identity_records
    Auditing::AuditEvent.delete_all
    Identity::OauthTransaction.delete_all
    Identity::Session.delete_all
    Identity::ProviderIdentity.delete_all
    Identity::User.delete_all
  end
end
