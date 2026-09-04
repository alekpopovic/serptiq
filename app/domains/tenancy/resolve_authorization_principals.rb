# frozen_string_literal: true

module Tenancy
  class ResolveAuthorizationPrincipals
    def call(organization_id:, membership_id:)
      membership = Membership.find_by(id: membership_id, organization_id: organization_id)
      return AuthorizationPrincipals.new(membership_id: nil, team_ids: []) unless membership&.active?

      team_ids = Team.joins(:team_memberships)
        .where(organization_id: organization_id, status: "active", archived_at: nil)
        .where(team_memberships: { membership_id: membership.id, removed_at: nil })
        .order(:id)
        .distinct
        .pluck(:id)
      AuthorizationPrincipals.new(membership_id: membership.id, team_ids: team_ids)
    end
  end
end
