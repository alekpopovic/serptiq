# frozen_string_literal: true

module Authorization
  class RevokeRole
    def initialize(clock: -> { Time.current }, scope_registry: ScopeRegistry.new,
      grant_authority: GrantAuthority.new)
      @clock = clock
      @scope_registry = scope_registry
      @grant_authority = grant_authority
    end

    def call(actor_membership:, assignment_id:)
      organization_id = actor_membership.organization_id.to_s
      actor_id = actor_membership.id.to_s
      assignment = RoleAssignment.transaction do
        Tenancy::Public.verify_owner_invariant!(organization_id: organization_id)
        actor = active_actor!(organization_id, actor_id)
        record = RoleAssignment.lock.find_by!(id: assignment_id, organization_id: organization_id)
        scope = scope!(record)
        principal_type, principal = PrincipalResolver.new.resolve(
          organization_id: organization_id,
          grantee_type: record.grantee_type,
          grantee_id: record.grantee_id,
          require_active: false
        )
        @grant_authority.authorize_revoke!(
          actor: actor, principal: principal, grantee_type: principal_type,
          role: record.role, scope: scope
        )
        unless record.revoked_at
          record.update!(revoked_at: @clock.call, revoked_by_membership_id: actor.id)
        end
        emit(record, actor.id, outcome: "succeeded", operation: "revoke")
        record
      end
      assignment
    rescue StandardError => error
      if defined?(record) && record
        emit(record, actor_id, outcome: "denied", operation: "revoke",
          reason_code: error.respond_to?(:reason_code) ? error.reason_code : "role_assignment_invalid")
      end
      raise
    end

    private

    def active_actor!(organization_id, actor_id)
      organization = Tenancy::Public.authorization_organization(organization_id: organization_id)
      actor = Tenancy::Public.authorization_membership(
        organization_id: organization_id, membership_id: actor_id
      )
      raise AssignmentDenied.new(reason_code: "resource_unavailable") unless organization&.active?
      raise AssignmentDenied.new(reason_code: "membership_inactive") unless actor&.active?

      actor
    end

    def scope!(assignment)
      chain = @scope_registry.resolve_chain(
        organization_id: assignment.organization_id,
        scope_type: assignment.scope_type,
        scope_id: assignment.scope_id
      )
      raise AssignmentDenied.new(reason_code: "scope_mismatch") if chain.empty?

      chain.last
    end

    def emit(assignment, actor_id, outcome:, operation:, reason_code: nil)
      Audit.emit(
        "authorization.role_revoked",
        organization_id: assignment.organization_id,
        actor_id: actor_id,
        principal_type: assignment.grantee_type,
        principal_id: assignment.grantee_id,
        role_id: assignment.role_id,
        scope_type: assignment.scope_type,
        scope_id: assignment.scope_id,
        outcome: outcome,
        operation: operation,
        reason_code: reason_code,
        target_id: assignment.id
      )
    end
  end
end
