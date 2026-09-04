# frozen_string_literal: true

module Authorization
  class EffectivePermissionQuery
    EMPTY = EffectivePermissionSet.new(permission_keys: [], assignment_ids: []).freeze

    def initialize(clock: -> { Time.current }, scope_registry: ScopeRegistry.new)
      @clock = clock
      @scope_registry = scope_registry
    end

    def call(organization_id:, membership_id:, scope_type:, scope_id:, all_permission_scopes: false)
      organization = Tenancy::Public.authorization_organization(organization_id: organization_id)
      membership = Tenancy::Public.authorization_membership(
        organization_id: organization_id, membership_id: membership_id
      )
      return EMPTY unless organization&.active? && membership&.active?

      chain = @scope_registry.resolve_chain(
        organization_id: organization_id, scope_type: scope_type, scope_id: scope_id
      )
      return EMPTY unless chain.present? && chain.all?(&:active?)

      permission_scope = chain.last.type == "Organization" ? "organization" : "project"
      if membership.owner?
        keys = Permission.where(active: true)
        keys = keys.where(scope: permission_scope) unless all_permission_scopes
        return EffectivePermissionSet.new(permission_keys: keys.pluck(:key), assignment_ids: [], ownership: true)
      end

      principals = Tenancy::Public.authorization_principals(
        organization_id: organization_id, membership_id: membership_id
      )
      return EMPTY unless principals.active?

      rows = assignment_relation(
        organization_id: organization_id, principals: principals, chain: chain,
        permission_scope: permission_scope, all_permission_scopes: all_permission_scopes
      ).distinct.pluck("permissions.key", "role_assignments.id")
      EffectivePermissionSet.new(
        permission_keys: rows.map(&:first), assignment_ids: rows.map(&:last)
      )
    end

    private

    def assignment_relation(organization_id:, principals:, chain:, permission_scope:, all_permission_scopes:)
      relation = RoleAssignment.effective_at(@clock.call)
        .where(organization_id: organization_id, effect: "allow")
        .joins(role: :permissions)
        .where(roles: { archived_at: nil })
        .where(permissions: { active: true })
      relation = relation.where(permissions: { scope: permission_scope }) unless all_permission_scopes
      relation = constrain_principals(relation, principals)
      constrain_scopes(relation, chain)
    end

    def constrain_principals(relation, principals)
      direct = relation.where(grantee_type: "Membership", grantee_id: principals.membership_id)
      return direct if principals.team_ids.empty?

      teams = relation.where(grantee_type: "Team", grantee_id: principals.team_ids)
      direct.or(teams)
    end

    def constrain_scopes(relation, chain)
      predicates = chain.map do |scope|
        relation.where(scope_type: scope.type, scope_id: scope.id)
      end
      predicates.reduce { |combined, predicate| combined.or(predicate) }
    end
  end
end
