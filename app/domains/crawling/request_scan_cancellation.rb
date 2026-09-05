# frozen_string_literal: true

module Crawling
  class RequestScanCancellation
    def initialize(clock: -> { Time.current }, access: ScanAccess.new)
      @clock = clock
      @access = access
    end

    def call(actor_membership:, project_id:, scan_id:)
      scan = nil
      outbox = nil
      Scan.transaction do
        scan = Scan.lock.find_by!(
          organization_id: actor_membership&.organization_id,
          project_id: project_id,
          id: scan_id
        )
        context = @access.call(
          actor_membership: actor_membership,
          project_id: project_id,
          property_id: scan.property_id,
          environment_id: scan.environment_id,
          permission_key: "scans.cancel"
        )
        return scan if scan.status.in?(%w[cancel_requested canceled])

        target = ScanTransitionMatrix.cancellation_target(status: scan.status)
        raise Conflict.new(reason_code: "scan_transition_invalid") unless target

        from_status = scan.status
        now = @clock.call
        scan.assign_attributes(
          status: target,
          cancel_requested_at: now,
          canceled_at: target == "canceled" ? now : nil,
          urls_queued_count: target == "canceled" ? 0 : scan.urls_queued_count,
          urls_running_count: target == "canceled" ? 0 : scan.urls_running_count
        )
        scan.progress_sequence += 1
        scan.save!
        event_type = target == "canceled" ? "scan.canceled" : "scan.cancel_requested"
        _event, outbox = ScanLifecycleRecord.record!(
          scan: scan,
          event_type: event_type,
          from_status: from_status,
          actor_membership_id: context.actor_membership_id,
          command: "request_cancel",
          occurred_at: now
        )
      end
      ScanLifecycleRecord.enqueue(outbox)
      scan
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "scan_scope_unavailable"), cause: nil
    end
  end
end
