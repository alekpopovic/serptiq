# frozen_string_literal: true

module Billing
  class OperationalMetrics
    WEBHOOK_LAG_ALERT = 5.minutes

    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(emit: false)
      now = @clock.call
      oldest = WebhookEvent.actionable.minimum(:received_at)
      snapshot = OperationalMetricsSnapshot.new(
        webhook_lag_seconds: oldest ? [ (now - oldest).to_i, 0 ].max : 0,
        dead_letter_count: WebhookEvent.where(state: "dead_letter").count,
        repeated_failure_count: WebhookEvent.where(state: %w[retryable dead_letter])
          .where(attempt_count: 3..).count,
        drift_count: ReconciliationRun.where(state: %w[ambiguous missing failed]).count,
        alerting: false
      )
      snapshot = snapshot.with(alerting: alerting?(snapshot))
      emit(snapshot) if emit
      snapshot
    end

    private

    def alerting?(snapshot)
      snapshot.webhook_lag_seconds >= WEBHOOK_LAG_ALERT || snapshot.dead_letter_count.positive? ||
        snapshot.repeated_failure_count.positive? || snapshot.drift_count.positive?
    end

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
      Shared::Public.report_observability_failure(error, event_name: "billing.operations_snapshot")
    end

    def metric_events(snapshot)
      [
        [ "billing.webhook_lag", "webhook_lag", snapshot.webhook_lag_seconds,
          snapshot.webhook_lag_seconds >= WEBHOOK_LAG_ALERT ],
        [ "billing.dead_letters", "dead_letters", snapshot.dead_letter_count,
          snapshot.dead_letter_count.positive? ],
        [ "billing.projection_failures", "projection_failures", snapshot.repeated_failure_count,
          snapshot.repeated_failure_count.positive? ],
        [ "billing.reconciliation_drift", "reconciliation_drift", snapshot.drift_count,
          snapshot.drift_count.positive? ]
      ]
    end
  end
end
