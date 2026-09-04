# frozen_string_literal: true

module Billing
  OperationalMetricsSnapshot = Data.define(
    :webhook_lag_seconds, :dead_letter_count, :repeated_failure_count, :drift_count, :alerting
  ) do
    def initialize(webhook_lag_seconds:, dead_letter_count:, repeated_failure_count:, drift_count:, alerting:)
      super(
        webhook_lag_seconds: Integer(webhook_lag_seconds),
        dead_letter_count: Integer(dead_letter_count),
        repeated_failure_count: Integer(repeated_failure_count),
        drift_count: Integer(drift_count),
        alerting: !!alerting
      )
      freeze
    end
  end
end
