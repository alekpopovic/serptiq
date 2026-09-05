# frozen_string_literal: true

module Crawling
  class ScanCapacity
    ACTIVE_STATUSES = %w[admitted queued running cancel_requested].freeze

    def lock!(organization_id:, project_id:)
      advisory_lock!("scan-admission:global")
      advisory_lock!("scan-admission:organization:#{organization_id}")
      advisory_lock!("scan-admission:project:#{organization_id}:#{project_id}")
    end

    def check!(organization_id:, project_id:, limits:)
      reject!("global", limits.global) if active.count >= limits.global
      organization = active.where(organization_id: organization_id)
      reject!("organization", limits.organization) if organization.count >= limits.organization
      project = organization.where(project_id: project_id)
      reject!("project", limits.project) if project.count >= limits.project
      true
    end

    private

    def active
      Scan.where(status: ACTIVE_STATUSES)
    end

    def advisory_lock!(key)
      quoted = ActiveRecord::Base.connection.quote(key)
      ActiveRecord::Base.connection.execute(
        "SELECT pg_advisory_xact_lock(hashtextextended(#{quoted}, 0))"
      )
    end

    def reject!(scope, _limit)
      raise CapacityExceeded.new(scope: scope)
    end
  end
end
