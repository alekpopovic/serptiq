# frozen_string_literal: true

require "test_helper"

class ProviderIdentityClaimConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { delete_identity_records }
  teardown { delete_identity_records }

  test "simultaneous recent sessions cannot claim one provider subject for two users" do
    now = 1.second.from_now.change(usec: 0)
    first = issue_identity_session(at: now - 1.minute)
    second = issue_identity_session(at: now - 1.minute)
    observed = Identity::NormalizedIdentity.new(
      provider: "github",
      subject: "42424242",
      email: "shared-observation@example.test",
      email_verified: true,
      profile: { "login" => "shared-observation" }
    )
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = [ first, second ].map do |issued|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          user = Identity::AccountTransition.new(clock: -> { now }).call(
            normalized_identity: observed,
            link_session: issued.session
          )
          results << "linked:#{user.id}"
        rescue Identity::InvalidAccountLink => error
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
    identity = Identity::ProviderIdentity.sole
    assert_equal 1, outcomes.count { |outcome| outcome == "linked:#{identity.user_id}" }
    assert_equal 1, outcomes.count("provider_identity_owned_by_another_user")
    assert_includes [ first.session.user_id, second.session.user_id ], identity.user_id
    assert_equal "42424242", identity.provider_subject
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
