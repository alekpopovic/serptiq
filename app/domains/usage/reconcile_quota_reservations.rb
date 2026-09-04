# frozen_string_literal: true

module Usage
  class ReconcileQuotaReservations
    MAXIMUM_CHECKED = 10_000

    def call
      reservations = QuotaReservation.where(state: "finalized")
        .includes(:finalized_usage_event)
        .order(:id)
        .limit(MAXIMUM_CHECKED)
        .to_a
      inconsistent = reservations.count { |reservation| inconsistent?(reservation) }
      if inconsistent.positive?
        Shared::Public.emit_structured_event(
          "usage.quota_reconciliation_failed",
          severity: :error,
          outcome: "failed",
          operation: "reconcile",
          reason_code: "reservation_event_mismatch"
        )
      end
      [ reservations.length, inconsistent ]
    rescue StandardError => error
      Shared::Public.report_observability_failure(
        error,
        event_name: "usage.quota_reconciliation_failed"
      )
      raise
    end

    private

    def inconsistent?(reservation)
      event = reservation.finalized_usage_event
      return !event.nil? unless reservation.consumed_quantity.positive?
      return true unless event

      event.organization_id != reservation.organization_id ||
        event.usage_window_id != reservation.usage_window_id ||
        event.usage_meter_definition_id != reservation.usage_meter_definition_id ||
        event.usage_meter_rate_id != reservation.usage_meter_rate_id ||
        event.source_type != reservation.source_type ||
        event.source_id != reservation.source_id ||
        event.billed_quantity != reservation.consumed_quantity
    end
  end
end
