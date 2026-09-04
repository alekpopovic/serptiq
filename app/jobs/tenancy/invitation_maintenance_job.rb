# frozen_string_literal: true

module Tenancy
  class InvitationMaintenanceJob < ApplicationJob
    runs_on :maintenance

    def perform
      {
        expired_invitations: ExpireInvitations.new.call,
        deleted_rate_limit_buckets: InvitationRateLimitCleanup.new.call
      }
    end
  end
end
