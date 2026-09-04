# frozen_string_literal: true

require "test_helper"

class TeamMembershipConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { delete_tenancy_records }
  teardown { delete_tenancy_records }

  test "concurrent add and remove operations are idempotent" do
    owner = create_organization_for(slug: "concurrent-team")
    target = Tenancy::Public.create_membership(
      actor_membership: owner.membership,
      user: create_identity_user(display_name: "Concurrent Team Member")
    )
    team = Tenancy::Public.create_team(actor_membership: owner.membership, name: "Concurrent Team")

    add_results = run_concurrently do
      Tenancy::Public.add_team_member(
        actor_membership: owner.membership,
        team_id: team.id,
        membership_id: target.id
      ).changed?
    end
    assert_equal [ false, true ], add_results.sort_by(&:to_s)
    assert_equal 1, active_team_membership_count(team.id, target.id)

    remove_results = run_concurrently do
      Tenancy::Public.remove_team_member(
        actor_membership: owner.membership,
        team_id: team.id,
        membership_id: target.id
      ).changed?
    end
    assert_equal [ false, true ], remove_results.sort_by(&:to_s)
    assert_equal 0, active_team_membership_count(team.id, target.id)
  end

  private

  def run_concurrently(&operation)
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          results << operation.call
        rescue StandardError => error
          results << "unexpected:#{error.class.name}:#{error.message}"
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)
    2.times.map { results.pop }
  end

  def active_team_membership_count(team_id, membership_id)
    Tenancy::TeamMembership.uncached do
      Tenancy::TeamMembership.where(team_id: team_id, membership_id: membership_id, removed_at: nil).count
    end
  end

  def delete_tenancy_records
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE organizations, users CASCADE")
  end
end
