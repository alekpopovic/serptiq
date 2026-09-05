# frozen_string_literal: true

module Crawling
  class ScanLiveUpdate
    MINIMUM_INTERVAL = 2.seconds

    def initialize(clock: -> { Time.current }, broadcaster: nil)
      @clock = clock
      @broadcaster = broadcaster || lambda { |organization_id, scan_id|
        Turbo::StreamsChannel.broadcast_refresh_to("scan", organization_id, scan_id)
      }
    end

    def call(organization_id:, scan_id:, force: false)
      execution = StaticCrawlExecution.find_by(organization_id: organization_id, scan_id: scan_id)
      return false unless execution

      emit = false
      execution.with_lock do
        now = @clock.call
        next if force && execution.terminal? && execution.last_live_update_at &&
          execution.last_live_update_at >= execution.finished_at
        next if !force && execution.last_live_update_at &&
          execution.last_live_update_at > now - MINIMUM_INTERVAL

        execution.update_column(:last_live_update_at, now)
        emit = true
      end
      return false unless emit

      @broadcaster.call(organization_id, scan_id)
      Shared::Public.emit_structured_event(
        "crawler.static_progress",
        outcome: "succeeded",
        operation: force ? "terminal" : "checkpoint"
      )
      true
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "crawler.static_progress")
      false
    end
  end
end
