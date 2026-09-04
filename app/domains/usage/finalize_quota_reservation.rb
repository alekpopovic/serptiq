# frozen_string_literal: true

module Usage
  class FinalizeQuotaReservation < ReservationMutation
    def initialize(clock: -> { Time.current }, pool: QuotaPool.new,
      idempotency: ReservationIdempotency.new, quantities: ReservationQuantity.new,
      recorder: nil)
      initialize_support(clock: clock, pool: pool, idempotency: idempotency, quantities: quantities)
      @recorder = recorder || RecordEvent.new(clock: clock)
    end

    def call(organization_id:, reservation_id:, idempotency_key:, actual_quantity:,
      occurred_at:, at: @clock.call, metadata: {})
      now = validate_time!(at)
      occurred = validate_time!(occurred_at, reason_code: "usage_reservation_occurrence_invalid")
      reservation = find_reservation(organization_id, reservation_id)
      validate_occurrence!(reservation, occurred, now)
      actual = @quantities.billed(
        actual_quantity,
        weight: reservation.meter_rate.weight,
        allow_zero: true
      )
      normalized_metadata = Metadata.new.call(metadata)
      digest, checksum = operation_identity(
        kind: "finalize",
        organization_id: organization_id,
        reservation_id: reservation_id,
        idempotency_key: idempotency_key,
        attributes: {
          actual_quantity: actual,
          occurred_at: occurred,
          metadata: normalized_metadata
        }
      )
      existing = replay(
        organization_id: organization_id,
        reservation_id: reservation_id,
        digest: digest,
        checksum: checksum,
        kind: "finalize"
      )
      return existing if existing

      with_locked_reservation(organization_id: organization_id, reservation_id: reservation_id) do |locked|
        existing = replay(
          organization_id: organization_id,
          reservation_id: reservation_id,
          digest: digest,
          checksum: checksum,
          kind: "finalize"
        )
        next existing if existing

        ensure_held!(locked)
        balance = @pool.balance(window: locked.window, at: now)
        additional = if locked.expires_at > now
          [ actual - locked.held_quantity, BigDecimal("0") ].max
        else
          actual
        end
        ensure_capacity!(reservation: locked, requested: additional, at: now, balance: balance)
        target_held = [ locked.held_quantity, actual ].max
        event = record_usage(locked, actual_quantity, actual, occurred, digest, normalized_metadata)
        locked.update!(
          requested_quantity: target_held,
          held_quantity: target_held,
          consumed_quantity: actual,
          released_quantity: target_held - actual,
          finalized_usage_event_id: event&.id,
          finalized_at: now,
          state: "finalized"
        )
        create_operation!(
          reservation: locked,
          kind: "finalize",
          digest: digest,
          checksum: checksum,
          quantity: actual,
          at: now
        )
        locked
      end
    rescue ActiveRecord::RecordNotUnique
      replay(
        organization_id: organization_id,
        reservation_id: reservation_id,
        digest: digest,
        checksum: checksum,
        kind: "finalize"
      ) || raise
    rescue ActiveRecord::StatementInvalid => error
      translate_statement_error(error, reason_code: "usage_reservation_finalization_invalid")
    end

    private

    def find_reservation(organization_id, reservation_id)
      validate_identifiers!(organization_id, reservation_id)
      QuotaReservation.includes(:meter_rate, window: :meter_definition).find_by!(
        id: reservation_id,
        organization_id: organization_id
      )
    rescue ActiveRecord::RecordNotFound
      raise Invalid.new(reason_code: "usage_reservation_not_found"), cause: nil
    end

    def validate_occurrence!(reservation, occurred_at, finalized_at)
      valid = reservation.window.starts_at <= occurred_at && occurred_at < reservation.window.ends_at &&
        occurred_at <= finalized_at
      raise Invalid.new(reason_code: "usage_reservation_occurrence_invalid") unless valid
    end

    def record_usage(reservation, raw_actual, billed_actual, occurred_at, operation_digest, metadata)
      return if billed_actual.zero?

      @recorder.call(
        window: reservation.window,
        idempotency_key: "quota-finalize:#{reservation.id}:#{operation_digest}",
        quantity: raw_actual,
        source: SourceReference.new(
          organization_id: reservation.source_organization_id,
          type: reservation.source_type,
          id: reservation.source_id
        ),
        occurred_at: occurred_at,
        metadata: metadata,
        meter_rate: reservation.meter_rate
      )
    end
  end
end
