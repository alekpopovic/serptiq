# frozen_string_literal: true

module Projects
  class ProjectAuthorization
    def authorize!(actor_membership:, permission_key:, project: nil)
      organization_id = actor_membership&.organization_id&.to_s
      membership_id = actor_membership&.id&.to_s
      organization = Tenancy::Public.authorization_organization(organization_id: organization_id)
      membership = Tenancy::Public.authorization_membership(
        organization_id: organization_id, membership_id: membership_id
      )
      raise ProjectAccessDenied unless organization&.active? && membership&.active?

      Authorization::Public.authorize_access!(
        actor_membership: membership,
        permission_key: permission_key,
        organization: organization,
        project: project
      )
    end
  end
end
