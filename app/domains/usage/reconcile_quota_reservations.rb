# frozen_string_literal: true

module Usage
  class ReconcileQuotaReservations
    MAXIMUM_CHECKED = 10_000

    def call
      reservations = QuotaReservation.where(state: %w[finalized expired])
        .includes(:finalized_usage_event, allocations: :usage_event)
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
      allocation_events = reservation.allocations.select(&:consumed?).map(&:usage_event)
      return true if allocation_events.any?(&:nil?)

      events = allocation_events.compact
      events << reservation.finalized_usage_event if reservation.finalized_usage_event
      valid_context = events.all? do |event|
        event.organization_id == reservation.organization_id &&
          event.source_type == reservation.source_type && event.source_id == reservation.source_id
      end
      !valid_context || events.sum(&:billed_quantity) != reservation.consumed_quantity
    end
  end
end
