# frozen_string_literal: true

require "test_helper"

class RoleAssignmentConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_tenant_data
    Authorization::Public.sync_catalog
  end

  teardown { truncate_tenant_data }

  test "concurrent duplicate assignment and revocation converge on one grant" do
    owner = create_organization_for(slug: "concurrent-role-assignment")
    member = Tenancy::Public.create_membership(
      actor_membership: owner.membership,
      user: create_identity_user(display_name: "Concurrent Role Member")
    )
    project_id = SecureRandom.uuid
    Authorization::Public.register_scope(
      organization_id: owner.organization.id,
      scope_type: "Project",
      scope_id: project_id
    )
    viewer = Authorization::Role.find_by!(system: true, key: "viewer")

    assignment_ids = run_concurrently do
      Authorization::Public.assign_role(
        actor_membership: owner.membership,
        grantee_type: "Membership",
        grantee_id: member.id,
        role_id: viewer.id,
        scope_type: "Project",
        scope_id: project_id
      ).id
    end
    assert_equal 1, assignment_ids.uniq.length
    assert_equal 1, active_assignment_count

    revoke_times = run_concurrently do
      Authorization::Public.revoke_role(
        actor_membership: owner.membership,
        assignment_id: assignment_ids.first
      ).revoked_at
    end
    refute revoke_times.any? { |value| value.to_s.start_with?("unexpected:") }, revoke_times.inspect
    assert_equal 1, revoke_times.uniq.length
    assert_equal 0, active_assignment_count
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

  def truncate_tenant_data
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE organizations, users CASCADE"
    )
  end

  def active_assignment_count
    Authorization::RoleAssignment.uncached do
      Authorization::RoleAssignment.where(revoked_at: nil).count
    end
  end
end
