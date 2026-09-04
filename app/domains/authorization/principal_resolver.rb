# frozen_string_literal: true

module Authorization
  class PrincipalResolver
    def resolve(organization_id:, grantee_type:, grantee_id:, require_active: true)
      type = grantee_type.to_s.classify
      principal = case type
      when "Membership"
        Tenancy::Public.authorization_membership(
          organization_id: organization_id, membership_id: grantee_id
        )
      when "Team"
        Tenancy::Public.authorization_team(organization_id: organization_id, team_id: grantee_id)
      end
      raise AssignmentDenied.new(reason_code: "scope_mismatch") unless principal
      if require_active && !principal.active?
        raise AssignmentDenied.new(reason_code: "principal_inactive")
      end

      [ type, principal ].freeze
    end
  end
end
