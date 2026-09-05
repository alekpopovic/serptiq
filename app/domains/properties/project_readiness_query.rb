# frozen_string_literal: true

module Properties
  class ProjectReadinessQuery
    def initialize(read_access: PropertyReadAccess.new, authorization: PropertyAuthorization.new)
      @read_access = read_access
      @authorization = authorization
    end

    def call(actor_membership:, project_id:)
      project = @authorization.project!(actor_membership: actor_membership, project_id: project_id)
      visibility = @read_access.visibility(actor_membership: actor_membership, project: project)
      raise PropertyAccessDenied unless visibility.accessible?

      relation = Property.where(organization_id: project.organization_id, project_id: project.id)
      relation = relation.where(id: visibility.property_ids) unless visibility.all_properties?
      grouped = relation.group(:status, :kind, :verification_status).count
      website_ids = relation.active.website_family.select(:id)
      environments = Environment.active.where(
        organization_id: project.organization_id,
        project_id: project.id,
        property_id: website_ids
      ).group(:primary).count

      ProjectReadiness.new(
        project_id: project.id,
        total_count: grouped.values.sum,
        active_count: grouped.sum { |(status, _kind, _verification), count| status == "active" ? count : 0 },
        website_count: grouped.sum do |(status, kind, _verification), count|
          status == "active" && kind.in?(%w[website web_application]) ? count : 0
        end,
        verified_website_count: grouped.sum do |(status, kind, verification), count|
          status == "active" && kind.in?(%w[website web_application]) && verification == "verified" ? count : 0
        end,
        active_environment_count: environments.values.sum,
        primary_environment_count: environments.fetch(true, 0)
      )
    end
  end
end
