# frozen_string_literal: true

require "test_helper"

class OwnershipTransferConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    Authorization::Public.sync_catalog
    @now = 1.second.from_now.change(usec: 0)
    @owner_user = create_identity_user
    @owner = create_organization_for(user: @owner_user, slug: "ownership-concurrency")
    @target = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Concurrent New Owner")
    )
    @session = issue_identity_session(user: @owner_user, at: @now - 1.minute)
    @decision = Authorization::Public.policy(
      actor_membership: @owner.membership,
      organization: @owner.organization
    ).decision(permission_key: "organization.transfer")
  end

  teardown { truncate_records }

  test "competing transfers serialize and leave exactly one current owner" do
    ready = Queue.new
    start = Queue.new
    outcomes = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          Tenancy::TransferOwnership.new(
            clock: -> { @now },
            notifier: ->(_) { true }
          ).call(
            actor_membership: @owner.membership,
            target_membership_id: @target.id,
            current_session: @session.session,
            session_metadata: Identity::SessionMetadata.empty,
            authorization: @decision,
            confirmation: Tenancy::TransferOwnership::CONFIRMATION
          )
          outcomes << "transferred"
        rescue Identity::RecentAuthenticationRequired, Tenancy::OwnershipTransferDenied => error
          outcomes << error.reason_code
        rescue StandardError => error
          outcomes << "unexpected:#{error.class.name}:#{error.message}"
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)

    results = 2.times.map { outcomes.pop }
    assert_equal 1, results.count("transferred"), results.inspect
    assert_equal 1, results.count("recent_authentication_required")
    assert_empty results.grep(/unexpected/)
    assert_equal @target.id, @owner.organization.reload.current_ownership.membership_id
    assert_equal 1, Tenancy::OrganizationOwnership.where(
      organization_id: @owner.organization.id,
      ended_at: nil
    ).count
  end

  private

  def truncate_records
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE organizations, users CASCADE")
  end
end
