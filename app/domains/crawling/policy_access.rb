# frozen_string_literal: true

module Crawling
  class PolicyAccess
    def call(actor_membership:, project_id:, property_id:, environment_id:)
      organization_id = actor_membership&.organization_id
      project = Projects::Public.reference(
        organization_id: organization_id, project_id: project_id
      )
      property = Properties::Public.reference(
        organization_id: organization_id, project_id: project_id, property_id: property_id
      )
      environment = Properties::Public.environment_reference(
        organization_id: organization_id, project_id: project_id,
        property_id: property_id, environment_id: environment_id
      )
      unless project&.active? && property&.active? &&
          property.kind.in?(%w[website web_application]) && environment&.active?
        raise AccessDenied.new(reason_code: "crawl_policy_scope_unavailable")
      end

      authorization = Authorization::Public.authorize_access!(
        actor_membership: actor_membership,
        permission_key: "scans.configure",
        organization: organization_id,
        project: project,
        property: property,
        entitlement_key: "crawl.manual"
      )
      PolicyContext.new(
        project: project, property: property, environment: environment,
        authorization: authorization
      )
    end
  end
end
