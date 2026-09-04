# frozen_string_literal: true

module Projects
  class ProjectDirectory
    PER_PAGE = 25
    QUERY_LIMIT = 80

    def initialize(read_access: ProjectReadAccess.new, read_models: ProjectOperationalReadModels.new,
      authorization: ProjectAuthorization.new)
      @read_access = read_access
      @read_models = read_models
      @authorization = authorization
    end

    def page(actor_membership:, number: nil, query: nil)
      visibility = @read_access.visibility(actor_membership: actor_membership)
      relation = visible_relation(actor_membership.organization_id, visibility)
      term = query.to_s.strip.first(QUERY_LIMIT)
      relation = search(relation, term) if term.present?
      page = normalize_page(number)
      total_count = relation.count
      projects = relation.order(:name, :id).offset((page - 1) * PER_PAGE).limit(PER_PAGE).to_a
      snapshots = @read_models.call(project_ids: projects.map(&:id))
      ProjectPage.new(
        entries: projects.map { |project| summarize(project, snapshots.fetch(project.id)) },
        page: page,
        per_page: PER_PAGE,
        total_count: total_count,
        query: term
      )
    end

    def find(actor_membership:, project_id:)
      project = Project.find_by(
        id: project_id, organization_id: actor_membership&.organization_id
      )
      raise ProjectAccessDenied unless project

      @authorization.authorize!(
        actor_membership: actor_membership,
        permission_key: "projects.read",
        project: project
      )
      snapshot = @read_models.call(project_ids: [ project.id ]).fetch(project.id)
      summarize(project, snapshot)
    end

    private

    def visible_relation(organization_id, visibility)
      relation = Project.where(organization_id: organization_id)
      return relation if visibility.all_projects?

      relation.where(id: visibility.project_ids)
    end

    def search(relation, term)
      escaped = ActiveRecord::Base.sanitize_sql_like(term)
      relation.where("name ILIKE :term OR slug ILIKE :term", term: "%#{escaped}%")
    end

    def normalize_page(value)
      Integer(value || 1).clamp(1, 10_000)
    rescue ArgumentError, TypeError
      1
    end

    def summarize(project, snapshot)
      ProjectSummary.new(
        id: project.id,
        slug: project.slug,
        name: project.name,
        description: project.description,
        status: project.status,
        default_locale: project.default_locale,
        time_zone: project.time_zone,
        external_release_key: project.external_release_key,
        archived_at: project.archived_at,
        deletion_requested_at: project.deletion_requested_at,
        health_state: snapshot.health_state,
        property_count: snapshot.property_count,
        latest_scan_state: snapshot.latest_scan_state,
        latest_scan_at: snapshot.latest_scan_at
      )
    end
  end
end
