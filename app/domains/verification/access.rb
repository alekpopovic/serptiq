# frozen_string_literal: true

module Verification
  class Access
    Context = Data.define(:project, :property, :environment, :authorization) do
      def actor_membership_id
        authorization.authorization.actor_membership_id
      end
    end

    def call(actor_membership:, project_id:, property_id:, environment_id:, permission_key:)
      organization_id = actor_membership&.organization_id
      project = Projects::Public.reference(organization_id: organization_id, project_id: project_id)
      property = Properties::Public.reference(
        organization_id: organization_id, project_id: project_id, property_id: property_id
      )
      environment = Properties::Public.environment_reference(
        organization_id: organization_id,
        project_id: project_id,
        property_id: property_id,
        environment_id: environment_id
      )
      raise AccessDenied unless project && property && environment

      authorization = Authorization::Public.authorize_access!(
        actor_membership: actor_membership,
        permission_key: permission_key,
        organization: organization_id,
        project: project,
        property: property
      )
      Context.new(
        project: project, property: property, environment: environment, authorization: authorization
      )
    end
  end
end
