# frozen_string_literal: true

module Crawling
  class LatestScanObservation
    def initialize(access: ScanAccess.new)
      @access = access
    end

    def call(actor_membership:, project_id:)
      context = @access.call(
        actor_membership: actor_membership,
        project_id: project_id,
        permission_key: "scans.read"
      )
      scan = Scan.where(
        organization_id: context.project.organization_id,
        project_id: context.project.id
      ).order(requested_at: :desc, id: :desc).first
      return observation("no_data", "No scan yet", "No persisted scan observation exists yet.") unless scan

      from_scan(scan)
    end

    private

    def from_scan(scan)
      case scan.status
      when "requested", "admitted", "queued"
        observation("loading", scan.status.humanize, "The scan is preparing to run.", observed_at: scan.updated_at)
      when "running", "cancel_requested"
        detail = scan.status == "cancel_requested" ?
          "Cancellation is recorded and workers must stop cooperatively." :
          "Progress is a persisted batch checkpoint and may lag individual URL work."
        observation(
          "loading", scan.status.humanize, detail,
          count: scan.urls_processed_count, observed_at: scan.updated_at
        )
      when "completed"
        observation(
          "ready", "Completed", "The latest scan reached a completed business outcome.",
          count: scan.findings_count, observed_at: scan.completed_at
        )
      when "partially_completed"
        observation(
          "ready", "Partially completed", "The retained result is usable but some work did not complete.",
          count: scan.findings_count, observed_at: scan.completed_at
        )
      when "canceled"
        observation(
          "failed", "Canceled", "The scan ended by an explicit cancellation request.",
          observed_at: scan.canceled_at
        )
      when "failed"
        observation(
          "failed", "Failed", "The scan ended without a completed business result.",
          observed_at: scan.failed_at
        )
      end
    end

    def observation(state, label, detail, count: nil, observed_at: nil)
      ScanObservation.new(
        state: state, label: label, detail: detail, count: count, observed_at: observed_at
      )
    end
  end
end
