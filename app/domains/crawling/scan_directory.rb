# frozen_string_literal: true

module Crawling
  class ScanDirectory
    PER_PAGE = 25
    EVENT_LIMIT = 50
    MAX_PAGE = 10_000

    def initialize(access: ScanAccess.new)
      @access = access
    end

    def page(actor_membership:, project_id:, number: nil)
      context = authorize!(actor_membership, project_id)
      relation = Scan.where(
        organization_id: context.project.organization_id,
        project_id: context.project.id
      )
      page_number = normalize_page(number)
      ScanPage.new(
        entries: relation.order(requested_at: :desc, id: :desc)
          .offset((page_number - 1) * PER_PAGE).limit(PER_PAGE).map { |scan| summarize(scan) },
        page: page_number,
        per_page: PER_PAGE,
        total_count: relation.count
      )
    end

    def find(actor_membership:, project_id:, scan_id:)
      context = authorize!(actor_membership, project_id)
      scan = Scan.find_by!(
        organization_id: context.project.organization_id,
        project_id: context.project.id,
        id: scan_id
      )
      events = scan.events.order(sequence: :desc).limit(EVENT_LIMIT).map do |event|
        ScanEventSummary.new(
          sequence: event.sequence,
          event_type: event.event_type,
          from_status: event.from_status,
          to_status: event.to_status,
          occurred_at: event.occurred_at
        )
      end
      ScanDetail.new(
        summary: summarize(scan),
        initiator_type: scan.initiator_type,
        settings_digest: scan.settings_digest,
        entitlement_digest: scan.entitlement_digest,
        engine_version: scan.engine_version,
        rule_set_version: scan.rule_set_version,
        configuration_version: scan.configuration_version,
        release_id: scan.release_id,
        baseline_scan_id: scan.baseline_scan_id,
        progress_sequence: scan.progress_sequence,
        events: events
      )
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "scan_scope_unavailable"), cause: nil
    end

    private

    def authorize!(actor_membership, project_id)
      @access.call(
        actor_membership: actor_membership,
        project_id: project_id,
        permission_key: "scans.read"
      )
    end

    def summarize(scan)
      ScanSummary.new(
        id: scan.id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id,
        scan_type: scan.scan_type,
        status: scan.status,
        requested_at: scan.requested_at,
        started_at: scan.started_at,
        finished_at: scan.finished_at,
        failure_category: scan.failure_category,
        counters: scan.counters
      )
    end

    def normalize_page(value)
      Integer(value || 1).clamp(1, MAX_PAGE)
    rescue ArgumentError, TypeError
      1
    end
  end
end
