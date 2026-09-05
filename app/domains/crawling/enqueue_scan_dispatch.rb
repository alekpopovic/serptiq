# frozen_string_literal: true

module Crawling
  class EnqueueScanDispatch
    def initialize(job_class: ScanDispatchJob, clock: -> { Time.current })
      @job_class = job_class
      @clock = clock
    end

    def call(organization_id:, scan_id:)
      scan = Scan.find_by(organization_id: organization_id, id: scan_id)
      return false unless scan

      Scan.transaction do
        scan.lock!
        return true if scan.dispatch_enqueued_at.present? || scan.status != "admitted"

        attempted_at = @clock.call
        scan.update!(
          dispatch_attempted_at: attempted_at,
          dispatch_attempt_count: scan.dispatch_attempt_count + 1,
          dispatch_last_error_category: nil
        )
        @job_class.perform_later(organization_id: scan.organization_id, scan_id: scan.id)
        scan.update!(dispatch_enqueued_at: @clock.call)
      end
      true
    rescue StandardError => error
      record_failure(organization_id, scan_id)
      Shared::Public.report_observability_failure(error, event_name: "scan.dispatch_enqueue_failed")
      false
    end

    private

    def record_failure(organization_id, scan_id)
      scan = Scan.find_by(organization_id: organization_id, id: scan_id)
      return unless scan&.status == "admitted" && scan.dispatch_enqueued_at.nil?

      scan.update!(
        dispatch_attempted_at: @clock.call,
        dispatch_attempt_count: scan.dispatch_attempt_count + 1,
        dispatch_last_error_category: "enqueue_failed"
      )
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "scan.dispatch_failure_record_failed")
    end
  end
end
