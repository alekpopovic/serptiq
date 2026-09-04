# frozen_string_literal: true

module Authorization
  class AcceptInvitation
    def initialize(assigner: AssignRole.new)
      @assigner = assigner
    end

    def call(token:, user:, rate_limit_key:)
      RoleAssignment.transaction do
        accepted = Tenancy::Public.accept_invitation_with_access_intent(
          token: token, user: user, rate_limit_key: rate_limit_key
        ) { |result| apply_role_intent(result) if result.role_intent? }
        accepted.membership
      end
    end

    private

    def apply_role_intent(accepted)
      actor = Tenancy::Public.authorization_membership(
        organization_id: accepted.membership.organization_id,
        membership_id: accepted.invited_by_membership_id
      )
      raise AssignmentDenied.new(reason_code: "grant_authority_missing") unless actor

      role = Role.find_by!(system: true, key: accepted.initial_role_key)
      @assigner.call(
        actor_membership: actor,
        grantee_type: "Membership",
        grantee_id: accepted.membership.id,
        role_id: role.id,
        scope_type: accepted.initial_scope_type,
        scope_id: accepted.initial_scope_id
      )
    end
  end
end
