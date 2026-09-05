# frozen_string_literal: true

module Crawling
  ScanAccessContext = Data.define(:project, :property, :environment, :authorization) do
    def initialize(**attributes)
      super(**attributes)
      freeze
    end

    def actor_membership_id
      authorization.authorization.actor_membership_id
    end
  end

  class ScanAccess
    def call(actor_membership:, project_id:, property_id: nil, environment_id: nil,
      permission_key:, active_required: false)
      organization_id = actor_membership&.organization_id
      project = Projects::Public.reference(organization_id: organization_id, project_id: project_id)
      raise AccessDenied.new(reason_code: "scan_scope_unavailable") unless project

      property = nil
      environment = nil
      if property_id
        property = Properties::Public.reference(
          organization_id: organization_id, project_id: project.id, property_id: property_id
        )
        raise AccessDenied.new(reason_code: "scan_scope_unavailable") unless property
      end
      if environment_id
        environment = Properties::Public.environment_reference(
          organization_id: organization_id, project_id: project.id,
          property_id: property&.id, environment_id: environment_id
        )
        raise AccessDenied.new(reason_code: "scan_scope_unavailable") unless environment
      end
      if active_required && !(project.active? && property&.active? && environment&.active?)
        raise AccessDenied.new(reason_code: "scan_scope_unavailable")
      end

      authorization = Authorization::Public.authorize_access!(
        actor_membership: actor_membership,
        permission_key: permission_key,
        organization: organization_id,
        project: project,
        property: property
      )
      ScanAccessContext.new(
        project: project, property: property, environment: environment,
        authorization: authorization
      )
    end
  end
end
