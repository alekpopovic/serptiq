# frozen_string_literal: true

require "test_helper"

class OwnerInvariantConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "owner-invariant-concurrency")
    @administrators = 2.times.map { |index| administrator(index) }
  end

  teardown { truncate_records }

  test "concurrent administrators cannot suspend or remove the current owner" do
    outcomes = run_concurrently(@administrators.each_with_index.map do |administrator, index|
      -> {
        operation = index.zero? ? "suspend" : "remove"
        Tenancy::Public.change_membership_status(
          actor_membership: administrator,
          target_membership_id: @owner.membership.id,
          operation: operation,
          authorization: decision(administrator, operation)
        )
        "unexpected_success"
      }
    end)

    assert_equal [ "last_owner_transfer_required", "last_owner_transfer_required" ], outcomes.sort
    assert_predicate @owner.membership.reload, :active?
    assert_predicate @owner.membership, :owner?
    assert_equal 1, Tenancy::OrganizationOwnership.where(
      organization_id: @owner.organization.id,
      ended_at: nil
    ).count
  end

  test "concurrent revocation of an additive owner role never removes ownership" do
    assignment = Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: @owner.membership.id,
      role_id: Authorization::Role.find_by!(key: "viewer").id,
      scope_type: "Organization",
      scope_id: @owner.organization.id
    )

    outcomes = run_concurrently(2.times.map do
      -> {
        Authorization::Public.revoke_role(
          actor_membership: @owner.membership,
          assignment_id: assignment.id
        ).revoked_at.to_s
      }
    end)

    assert_equal 1, outcomes.uniq.length
    assert_predicate @owner.membership.reload, :owner?
    assert_empty Tenancy::Public.ownership_consistency_issues
  end

  private

  def administrator(index)
    membership = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Concurrent Administrator #{index}")
    )
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: membership.id,
      role_id: Authorization::Role.find_by!(key: "organization_admin").id,
      scope_type: "Organization",
      scope_id: @owner.organization.id
    )
    membership
  end

  def decision(administrator, operation)
    permission = operation == "remove" ? "members.remove" : "members.update"
    Authorization::Public.policy(
      actor_membership: administrator,
      organization: @owner.organization
    ).decision(permission_key: permission)
  end

  def run_concurrently(operations)
    ready = Queue.new
    start = Queue.new
    outcomes = Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          outcomes << operation.call
        rescue Tenancy::LastOwnerConflict => error
          outcomes << error.reason_code
        rescue StandardError => error
          outcomes << "unexpected:#{error.class.name}:#{error.message}"
        end
      end
    end
    operations.length.times { ready.pop }
    operations.length.times { start << true }
    threads.each(&:join)
    operations.length.times.map { outcomes.pop }
  end

  def truncate_records
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE organizations, users CASCADE")
  end
end
