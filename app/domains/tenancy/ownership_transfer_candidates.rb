# frozen_string_literal: true

module Tenancy
  class OwnershipTransferCandidates
    LIMIT = 100

    def call(actor_membership:, authorization:)
      organization = AuthorizeMembershipAccess.new.call(
        membership: actor_membership,
        permission_key: "organization.transfer",
        authorization: authorization
      )
      Membership.where(organization_id: organization.id, status: "active")
        .where.not(id: actor_membership.id)
        .order(:display_name, :id)
        .limit(LIMIT)
        .map { |membership| summarize(membership) }
        .freeze
    end

    private

    def summarize(membership)
      MembershipSummary.new(
        id: membership.id,
        display_name: membership.display_name,
        status: membership.status,
        accepted_at: membership.accepted_at,
        suspended_at: membership.suspended_at,
        removed_at: membership.removed_at,
        owner: false
      )
    end
  end
end
