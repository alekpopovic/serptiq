# frozen_string_literal: true

module Authorization
  class VisiblePropertyScopes
    PERMISSION = "properties.read"

    def initialize(clock: -> { Time.current }, scope_registry: ScopeRegistry.new)
      @clock = clock
      @scope_registry = scope_registry
    end

    def call(organization_id:, membership_id:, project_id:)
      organization = Tenancy::Public.authorization_organization(organization_id: organization_id)
      membership = Tenancy::Public.authorization_membership(
        organization_id: organization_id, membership_id: membership_id
      )
      return none unless organization&.active? && membership&.active?

      chain = @scope_registry.resolve_chain(
        organization_id: organization_id, scope_type: "Project", scope_id: project_id
      )
      return none unless chain.length == 2 && chain.all?(&:active?)
      return all if membership.owner?

      principals = Tenancy::Public.authorization_principals(
        organization_id: organization_id, membership_id: membership_id
      )
      return none unless principals.active?

      grants = permission_grants(organization_id: organization_id, principals: principals)
      inherited = grants.where(scope_type: "Organization", scope_id: organization_id)
        .or(grants.where(scope_type: "Project", scope_id: project_id))
      return all if inherited.exists?

      ids = grants.where(scope_type: "Property").pluck(:scope_id)
      active_ids = ScopeReference.where(
        organization_id: organization_id,
        project_id: project_id,
        scope_type: "Property",
        status: "active",
        id: ids
      ).pluck(:id)
      Public::PropertyVisibility.new(all_properties: false, property_ids: active_ids)
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
      Public::PropertyVisibility.new(all_properties: true)
    end

    def none
      Public::PropertyVisibility.new(all_properties: false)
    end
  end
end
