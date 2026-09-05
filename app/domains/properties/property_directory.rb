# frozen_string_literal: true

module Properties
  class PropertyDirectory
    PER_PAGE = 25
    QUERY_LIMIT = 80
    CONFIGURATION_INCLUDES = %i[
      website_property_config android_property_config ios_property_config environments
    ].freeze

    def initialize(read_access: PropertyReadAccess.new, authorization: PropertyAuthorization.new)
      @read_access = read_access
      @authorization = authorization
    end

    def page(actor_membership:, project_id:, number: nil, query: nil)
      project = @authorization.project!(actor_membership: actor_membership, project_id: project_id)
      visibility = @read_access.visibility(actor_membership: actor_membership, project: project)
      raise PropertyAccessDenied unless visibility.accessible?

      relation = visible_relation(project, visibility)
      term = query.to_s.strip.first(QUERY_LIMIT)
      relation = search(relation, term) if term.present?
      page = normalize_page(number)
      total_count = relation.count
      records = relation.includes(*CONFIGURATION_INCLUDES)
        .order(:display_name, :id)
        .offset((page - 1) * PER_PAGE)
        .limit(PER_PAGE)
        .to_a
      PropertyPage.new(
        entries: records.map { |record| summarize(record) },
        page: page,
        per_page: PER_PAGE,
        total_count: total_count,
        query: term
      )
    end

    def find(actor_membership:, project_id:, property_id:)
      property = Property.includes(*CONFIGURATION_INCLUDES).find_by(
        id: property_id,
        project_id: project_id,
        organization_id: actor_membership&.organization_id
      )
      raise PropertyAccessDenied unless property

      project = @authorization.project!(actor_membership: actor_membership, project_id: project_id)
      @authorization.authorize!(
        actor_membership: actor_membership,
        permission_key: "properties.read",
        project: project,
        property: property
      )
      summarize(property)
    end

    private

    def visible_relation(project, visibility)
      relation = Property.where(
        organization_id: project.organization_id,
        project_id: project.id
      )
      return relation if visibility.all_properties?

      relation.where(id: visibility.property_ids)
    end

    def search(relation, term)
      escaped = ActiveRecord::Base.sanitize_sql_like(term)
      relation.where("display_name ILIKE :term OR kind ILIKE :term", term: "%#{escaped}%")
    end

    def normalize_page(value)
      Integer(value || 1).clamp(1, 10_000)
    rescue ArgumentError, TypeError
      1
    end

    def summarize(property)
      configuration = property.configuration_record
      raise PropertyTransitionInvalid.new(reason_code: "property_configuration_missing") unless configuration

      PropertySummary.new(
        id: property.id,
        project_id: property.project_id,
        display_name: property.display_name,
        kind: property.kind,
        status: property.status,
        verification_status: property.verification_status,
        verified_at: property.verified_at,
        archived_at: property.archived_at,
        deletion_requested_at: property.deletion_requested_at,
        configuration: configuration.value,
        environments: property.environments.sort_by do |environment|
          [ environment.primary? ? 0 : 1, environment.kind, environment.display_name, environment.id ]
        end.map { |environment| summarize_environment(environment) }
      )
    end

    def summarize_environment(environment)
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
