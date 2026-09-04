# frozen_string_literal: true

module Authorization
  class VisibleProjectScopes
    PERMISSION = "projects.read"

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, membership_id:)
      organization = Tenancy::Public.authorization_organization(organization_id: organization_id)
      membership = Tenancy::Public.authorization_membership(
        organization_id: organization_id, membership_id: membership_id
      )
      return none unless organization&.active? && membership&.active?
      return all if membership.owner?

      principals = Tenancy::Public.authorization_principals(
        organization_id: organization_id, membership_id: membership_id
      )
      return none unless principals.active?

      grants = permission_grants(organization_id: organization_id, principals: principals)
      return all if grants.where(scope_type: "Organization", scope_id: organization_id).exists?

      ids = grants.where(scope_type: "Project").pluck(:scope_id)
      active_ids = ScopeReference.where(
        organization_id: organization_id,
        scope_type: "Project",
        status: "active",
        id: ids
      ).pluck(:id)
      Public::ProjectVisibility.new(all_projects: false, project_ids: active_ids)
    end

    private

    def permission_grants(organization_id:, principals:)
      relation = RoleAssignment.effective_at(@clock.call)
        .where(organization_id: organization_id, effect: "allow")
        .joins(role: :permissions)
        .where(roles: { archived_at: nil }, permissions: { active: true, key: PERMISSION })
      direct = relation.where(grantee_type: "Membership", grantee_id: principals.membership_id)
      return direct if principals.team_ids.empty?

      direct.or(relation.where(grantee_type: "Team", grantee_id: principals.team_ids))
    end

    def all
      Public::ProjectVisibility.new(all_projects: true)
    end

    def none
      Public::ProjectVisibility.new(all_projects: false)
    end
  end
end
