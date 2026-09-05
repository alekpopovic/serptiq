# frozen_string_literal: true

module Auditing
  class ProjectActivityQuery
    PER_PAGE = 10
    MAX_PAGE = 10_000

    def call(organization_id:, project_id:, authorization:, page: nil)
      authorize!(organization_id, project_id, authorization)
      relation = AuditEvent.where(
        organization_id: organization_id,
        target_type: "Project",
        target_id: project_id
      )
      number = normalize_page(page)
      total_count = relation.count
      entries = relation.order(occurred_at: :desc, id: :desc)
        .offset((number - 1) * PER_PAGE)
        .limit(PER_PAGE)
        .map do |event|
          ProjectActivityEntry.new(
            action: event.action,
            result: event.result,
            target_type: event.target_type,
            occurred_at: event.occurred_at
          )
        end
      ProjectActivityPage.new(
        entries: entries,
        page: number,
        per_page: PER_PAGE,
        total_count: total_count
      )
    end

    private

    def authorize!(organization_id, project_id, authorization)
      valid = authorization&.allow? && authorization.permission_key == "projects.read" &&
        authorization.organization_id.to_s == organization_id.to_s &&
        authorization.scope_type == "Project" && authorization.scope_id.to_s == project_id.to_s
      raise AccessDenied unless valid
    end

    def normalize_page(value)
      Integer(value || 1).clamp(1, MAX_PAGE)
    rescue ArgumentError, TypeError
      1
    end
  end
end
