# frozen_string_literal: true

module Properties
  class PropertyAuthorization
    def project!(actor_membership:, project_id:)
      project = Projects::Public.reference(
        organization_id: actor_membership&.organization_id,
        project_id: project_id
      )
      raise PropertyAccessDenied unless project

      project
    end

    def authorize!(actor_membership:, permission_key:, project:, property: nil)
      Authorization::Public.authorize_access!(
        actor_membership: actor_membership,
        permission_key: permission_key,
        organization: actor_membership&.organization_id,
        project: project,
        property: property
      )
    end
  end
end
