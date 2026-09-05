# frozen_string_literal: true

module Crawling
  class PressureMetrics
    STALE_ALERT_THRESHOLD = 10

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(emit: false)
      now = @clock.call
      maximum_wait = PressureState.where("next_fetch_at > ? OR backoff_until > ?", now, now)
        .pluck(:next_fetch_at, :backoff_until).flatten.compact.max
      snapshot = PressureMetricsSnapshot.new(
        active_permits: FetchPermit.active_at(now).count,
        stale_permits: FetchPermit.stale_at(now).count,
        throttled_scans: Scan.where.not(throttled_at: nil).count,
        backed_off_hosts: PressureState.where(scope_type: "host").backed_off_at(now).count,
        disabled_hosts: PressureState.disabled.where(scope_type: "host").count,
        global_disabled: PressureState.disabled.where(scope_type: "global").exists?,
        maximum_wait_seconds: maximum_wait ? [ (maximum_wait - now).ceil, 0 ].max : 0,
        alerting: false
      )
      snapshot = snapshot.with(
        alerting: snapshot.stale_permits >= STALE_ALERT_THRESHOLD || snapshot.global_disabled
      )
      emit(snapshot) if emit
      snapshot
    end

    private

    def emit(snapshot)
      metric_events(snapshot).each do |event_name, operation, value, alert|
        Shared::Public.emit_structured_event(
          event_name,
          severity: alert ? :warn : :info,
          outcome: alert ? "failed" : "succeeded",
          operation: operation,
          reason_code: alert ? "threshold_exceeded" : "within_threshold",
          retry_count: value
        )
      end
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "crawler.pressure_snapshot")
    end

    def metric_events(snapshot)
      [
        [ "crawler.active_fetch_permits", "active_permits", snapshot.active_permits, false ],
        [ "crawler.stale_fetch_permits", "stale_permits", snapshot.stale_permits,
          snapshot.stale_permits >= STALE_ALERT_THRESHOLD ],
        [ "crawler.throttled_scans", "throttled_scans", snapshot.throttled_scans, false ],
        [ "crawler.backed_off_hosts", "backed_off_hosts", snapshot.backed_off_hosts, false ],
        [ "crawler.disabled_hosts", "disabled_hosts", snapshot.disabled_hosts, false ],
        [ "crawler.global_kill_switch", "global_kill_switch", snapshot.global_disabled ? 1 : 0,
          snapshot.global_disabled ]
      ]
    end
  end
end
