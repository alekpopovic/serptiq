# frozen_string_literal: true

require "test_helper"

class TenancyInvitationMaintenanceJobTest < ActiveJob::TestCase
  test "expires pending invitations and removes elapsed rate buckets" do
    now = Time.current.change(usec: 0)
    owner = create_organization_for
    issued = travel_to(now - 8.days) do
      Tenancy::IssueInvitation.new(
        clock: -> { now - 8.days }, delivery: ->(**) { }
      ).call(actor_membership: owner.membership, email: "maintenance@example.test")
    end
    Tenancy::InvitationRateLimitBucket.update_all(expires_at: now - 1.second)

    travel_to(now) do
      result = Tenancy::InvitationMaintenanceJob.perform_now
      assert_equal 1, result.fetch(:expired_invitations)
      assert_operator result.fetch(:deleted_rate_limit_buckets), :>=, 1
    end
    assert issued.invitation.reload.expired?
    assert_empty Tenancy::InvitationRateLimitBucket.all
    assert_equal "maintenance", Tenancy::InvitationMaintenanceJob.new.queue_name
  end
end
