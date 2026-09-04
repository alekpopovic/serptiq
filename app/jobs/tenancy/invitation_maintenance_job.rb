# frozen_string_literal: true

module Tenancy
  class InvitationMaintenanceJob < ApplicationJob
    runs_on :maintenance
    system_authorization :global_invitation_maintenance,
      reason: "expires tenant invitations and deletes non-tenant delivery rate buckets"

    def perform
      {
        expired_invitations: ExpireInvitations.new.call,
        deleted_rate_limit_buckets: InvitationRateLimitCleanup.new.call
      }
    end
  end
end
