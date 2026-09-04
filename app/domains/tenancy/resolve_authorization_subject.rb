# frozen_string_literal: true

module Tenancy
  class ResolveAuthorizationSubject
    def organization(organization_id:)
      record = Organization.find_by(id: organization_id)
      record && AuthorizationOrganization.new(id: record.id, status: record.status)
    end

    def membership(organization_id:, membership_id:)
      record = Membership.find_by(id: membership_id, organization_id: organization_id)
      return unless record

      owner = OrganizationOwnership.where(
        organization_id: organization_id, membership_id: record.id, ended_at: nil
      ).exists?
      AuthorizationMembership.new(
        id: record.id, organization_id: record.organization_id, status: record.status, owner: owner
      )
    end

    def team(organization_id:, team_id:)
      record = Team.find_by(id: team_id, organization_id: organization_id)
      return unless record

      member_ids = TeamMembership.where(
        organization_id: organization_id, team_id: record.id, removed_at: nil
      ).pluck(:membership_id)
      AuthorizationTeam.new(
        id: record.id, organization_id: record.organization_id, status: record.status, member_ids: member_ids
      )
    end
  end
end
