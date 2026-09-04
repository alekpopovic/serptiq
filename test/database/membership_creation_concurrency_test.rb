# frozen_string_literal: true

require "test_helper"

class MembershipCreationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { delete_tenancy_records }
  teardown { delete_tenancy_records }

  test "concurrent creates produce one durable membership for an organization and user" do
    owner = create_organization_for(slug: "concurrent-membership")
    target_user = create_identity_user(display_name: "Concurrent Member")
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          membership = Tenancy::Public.create_membership(
            actor_membership: owner.membership,
            user: target_user
          )
          results << membership.id
        rescue Tenancy::MembershipAlreadyExists => error
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
    membership = Tenancy::Membership.find_by!(organization_id: owner.organization.id, user_id: target_user.id)
    assert_equal 1, outcomes.count(membership.id)
    assert_equal 1, outcomes.count("membership_already_exists")
    assert_equal 1, Tenancy::Membership.where(organization_id: owner.organization.id, user_id: target_user.id).count
  end

  private

  def delete_tenancy_records
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE organizations, users CASCADE")
  end
end
