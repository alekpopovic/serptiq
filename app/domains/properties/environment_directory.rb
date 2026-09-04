# frozen_string_literal: true

module Properties
  class EnvironmentDirectory
    PER_PAGE = 25
    QUERY_LIMIT = 80

    def initialize(authorization: PropertyAuthorization.new)
      @authorization = authorization
    end

    def page(actor_membership:, project_id:, property_id:, number: nil, query: nil)
      property, project = authorized_property!(
        actor_membership: actor_membership,
        project_id: project_id,
        property_id: property_id,
        permission_key: "properties.read"
      )
      term = query.to_s.strip.first(QUERY_LIMIT)
      relation = scoped_relation(property)
      if term.present?
        escaped = ActiveRecord::Base.sanitize_sql_like(term)
        relation = relation.where(
          "display_name ILIKE :term OR key ILIKE :term OR kind ILIKE :term",
          term: "%#{escaped}%"
        )
      end
      page = normalize_page(number)
      total_count = relation.count
      entries = relation.order(primary: :desc, kind: :asc, display_name: :asc, id: :asc)
        .offset((page - 1) * PER_PAGE).limit(PER_PAGE).map { |record| summarize(record) }
      EnvironmentPage.new(
        entries: entries,
        page: page,
        per_page: PER_PAGE,
        total_count: total_count,
        query: term
      )
    end

    def find(actor_membership:, project_id:, property_id:, environment_id:)
      property, = authorized_property!(
        actor_membership: actor_membership,
        project_id: project_id,
        property_id: property_id,
        permission_key: "properties.read"
      )
      environment = scoped_relation(property).find_by(id: environment_id)
      raise PropertyAccessDenied unless environment

      summarize(environment)
    end

    private

    def authorized_property!(actor_membership:, project_id:, property_id:, permission_key:)
      property = Property.find_by(
        organization_id: actor_membership&.organization_id,
        project_id: project_id,
        id: property_id
      )
      raise PropertyAccessDenied unless property

      project = @authorization.project!(actor_membership: actor_membership, project_id: project_id)
      @authorization.authorize!(
        actor_membership: actor_membership,
        permission_key: permission_key,
        project: project,
        property: property
      )
      [ property, project ]
    end

    def scoped_relation(property)
      Environment.where(
        organization_id: property.organization_id,
        project_id: property.project_id,
        property_id: property.id
      )
    end

    def normalize_page(value)
      Integer(value || 1).clamp(1, 10_000)
    rescue ArgumentError, TypeError
      1
    end

    def summarize(environment)
      EnvironmentSummary.new(
        id: environment.id,
        property_id: environment.property_id,
        key: environment.key,
        kind: environment.kind,
        display_name: environment.display_name,
        primary: environment.primary?,
        status: environment.status,
        archived_at: environment.archived_at,
        origin: environment.origin_value
      )
    end
  end
end
