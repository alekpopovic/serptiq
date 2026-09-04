# frozen_string_literal: true

require "digest"

module Authorization
  class AssignRole
    def initialize(clock: -> { Time.current }, scope_registry: ScopeRegistry.new,
      principal_resolver: PrincipalResolver.new, grant_authority: GrantAuthority.new)
      @clock = clock
      @scope_registry = scope_registry
      @principal_resolver = principal_resolver
      @grant_authority = grant_authority
    end

    def call(actor_membership:, grantee_type:, grantee_id:, role_id:, scope_type:, scope_id:,
      expires_at: nil, effect: "allow")
      organization_id, actor_id = actor_identifiers(actor_membership)
      normalized_type = grantee_type.to_s.classify
      normalized_scope = scope_type.to_s.classify
      reject_deny!(effect)
      now = @clock.call
      raise AssignmentInvalid.new(reason_code: "assignment_expiry_invalid") if expires_at && expires_at <= now

      assignment = RoleAssignment.transaction do
        Tenancy::Public.verify_owner_invariant!(organization_id: organization_id)
        actor = active_actor!(organization_id, actor_id)
        principal_type, principal = @principal_resolver.resolve(
          organization_id: organization_id, grantee_type: normalized_type, grantee_id: grantee_id
        )
        scope = active_scope!(organization_id, normalized_scope, scope_id)
        role = Role.lock.find(role_id)
        @grant_authority.authorize!(
          actor: actor, principal: principal, grantee_type: principal_type, role: role, scope: scope
        )
        attributes = assignment_attributes(
          organization_id: organization_id, actor_id: actor.id, principal_type: principal_type,
          principal_id: principal.id, role: role, scope: scope, expires_at: expires_at
        )
        lock_assignment!(attributes)
        result = persist_assignment!(attributes, now)
        audit("authorization.role_assigned", result, actor.id, outcome: "succeeded", operation: "assign")
        result
      end
      assignment
    rescue ActiveRecord::RecordNotUnique
      assignment = RoleAssignment.find_by!(active_identity(attributes_from_call(
        actor_membership: actor_membership, grantee_type: normalized_type, grantee_id: grantee_id,
        role_id: role_id, scope_type: normalized_scope, scope_id: scope_id
      )))
      audit("authorization.role_assigned", assignment, actor_id, outcome: "succeeded", operation: "existing")
      assignment
    rescue StandardError => error
      audit_rejection(
        organization_id: organization_id, actor_id: actor_id, principal_type: normalized_type,
        principal_id: grantee_id, role_id: role_id, scope_type: normalized_scope,
        scope_id: scope_id, error: error
      )
      raise
    end

    private

    def actor_identifiers(actor_membership)
      unless actor_membership.respond_to?(:id) && actor_membership.respond_to?(:organization_id)
        raise AssignmentDenied.new(reason_code: "membership_inactive")
      end

      [ actor_membership.organization_id.to_s, actor_membership.id.to_s ].freeze
    end

    def active_actor!(organization_id, actor_id)
      organization = Tenancy::Public.authorization_organization(organization_id: organization_id)
      actor = Tenancy::Public.authorization_membership(
        organization_id: organization_id, membership_id: actor_id
      )
      raise AssignmentDenied.new(reason_code: "resource_unavailable") unless organization&.active?
      raise AssignmentDenied.new(reason_code: "membership_inactive") unless actor&.active?

      actor
    end

    def active_scope!(organization_id, scope_type, scope_id)
      chain = @scope_registry.resolve_chain(
        organization_id: organization_id, scope_type: scope_type, scope_id: scope_id,
        persist_organization: true
      )
      raise AssignmentDenied.new(reason_code: "scope_mismatch") if chain.empty?
      raise AssignmentDenied.new(reason_code: "resource_unavailable") unless chain.all?(&:active?)

      chain.last
    end

    def reject_deny!(effect)
      return if effect.to_s == "allow"

      raise AssignmentDenied.new(reason_code: "deny_not_supported")
    end

    def assignment_attributes(organization_id:, actor_id:, principal_type:, principal_id:, role:, scope:, expires_at:)
      {
        organization_id: organization_id,
        grantee_type: principal_type,
        grantee_id: principal_id,
        membership_grantee_id: principal_type == "Membership" ? principal_id : nil,
        team_grantee_id: principal_type == "Team" ? principal_id : nil,
        role_id: role.id,
        role_system: role.system?,
        role_organization_id: role.system? ? nil : organization_id,
        scope_type: scope.type,
        scope_id: scope.id,
        granted_by_membership_id: actor_id,
        expires_at: expires_at,
        effect: "allow"
      }
    end

    def lock_assignment!(attributes)
      fingerprint = active_identity(attributes).values.join(":")
      key = Digest::SHA256.hexdigest(fingerprint).first(16).to_i(16)
      key -= 2**64 if key >= 2**63
      RoleAssignment.connection.execute("SELECT pg_advisory_xact_lock(#{key})")
    end

    def persist_assignment!(attributes, now)
      existing = RoleAssignment.lock.find_by(active_identity(attributes))
      return existing if existing&.active_at?(now)

      if existing
        existing.update!(revoked_at: now, revoked_by_membership_id: attributes.fetch(:granted_by_membership_id))
      end
      RoleAssignment.create!(attributes.merge(created_at: now, updated_at: now))
    end

    def active_identity(attributes)
      attributes.slice(:organization_id, :grantee_type, :grantee_id, :role_id, :scope_type, :scope_id)
        .merge(revoked_at: nil)
    end

    def attributes_from_call(actor_membership:, grantee_type:, grantee_id:, role_id:, scope_type:, scope_id:)
      {
        organization_id: actor_membership.organization_id,
        grantee_type: grantee_type,
        grantee_id: grantee_id,
        role_id: role_id,
        scope_type: scope_type,
        scope_id: scope_id
      }
    end

    def audit(event, assignment, actor_id, outcome:, operation:, reason_code: nil)
      Audit.emit(
        event,
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

    def audit_rejection(organization_id:, actor_id:, principal_type:, principal_id:, role_id:,
      scope_type:, scope_id:, error:)
      return if [ organization_id, actor_id, principal_id, role_id, scope_id ].any?(&:blank?)

      Audit.emit(
        "authorization.role_assignment_rejected",
        organization_id: organization_id,
        actor_id: actor_id,
        principal_type: principal_type,
        principal_id: principal_id,
        role_id: role_id,
        scope_type: scope_type,
        scope_id: scope_id,
        outcome: "denied",
        operation: "assign",
        reason_code: error.respond_to?(:reason_code) ? error.reason_code : "role_assignment_invalid"
      )
    end
  end
end
