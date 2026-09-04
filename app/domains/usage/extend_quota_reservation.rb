# frozen_string_literal: true

module Usage
  class ExtendQuotaReservation < ReservationMutation
    MAXIMUM_LIFETIME = 7.days

    def initialize(clock: -> { Time.current }, pool: QuotaPool.new,
      idempotency: ReservationIdempotency.new, quantities: ReservationQuantity.new)
      initialize_support(clock: clock, pool: pool, idempotency: idempotency, quantities: quantities)
    end

    def call(organization_id:, reservation_id:, idempotency_key:, additional_quantity: 0,
      expires_at: nil, at: @clock.call)
      now = validate_time!(at)
      reservation = find_reservation(organization_id, reservation_id)
      additional = @quantities.billed(
        additional_quantity,
        weight: reservation.meter_rate.weight,
        allow_zero: true
      )
      requested_expiration = expires_at && validate_time!(expires_at)
      digest, checksum = operation_identity(
        kind: "extend",
        organization_id: organization_id,
        reservation_id: reservation_id,
        idempotency_key: idempotency_key,
        attributes: {
          additional_quantity: additional,
          expires_at: requested_expiration
        }
      )
      existing = replay(
        organization_id: organization_id,
        reservation_id: reservation_id,
        digest: digest,
        checksum: checksum,
        kind: "extend"
      )
      return existing if existing

      with_locked_reservation(organization_id: organization_id, reservation_id: reservation_id) do |locked|
        existing = replay(
          organization_id: organization_id,
          reservation_id: reservation_id,
          digest: digest,
          checksum: checksum,
          kind: "extend"
        )
        next existing if existing

        ensure_held!(locked)
        raise Conflict.new(reason_code: "usage_reservation_expired") unless locked.expires_at > now

        target_expiration = requested_expiration || locked.expires_at
        valid_expiration = target_expiration >= locked.expires_at &&
          target_expiration <= locked.admitted_at + MAXIMUM_LIFETIME &&
          target_expiration <= locked.window.ends_at
        changed = additional.positive? || target_expiration > locked.expires_at
        raise Invalid.new(reason_code: "usage_reservation_extension_invalid") unless
          valid_expiration && changed

        ensure_capacity!(reservation: locked, requested: additional, at: now)
        target_quantity = locked.held_quantity + additional
        locked.update!(
          requested_quantity: target_quantity,
          held_quantity: target_quantity,
          expires_at: target_expiration
        )
        create_operation!(
          reservation: locked,
          kind: "extend",
          digest: digest,
          checksum: checksum,
          quantity: additional,
          requested_expires_at: requested_expiration,
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
        kind: "extend"
      ) || raise
    rescue ActiveRecord::StatementInvalid => error
      translate_statement_error(error, reason_code: "usage_reservation_transition_invalid")
    end

    private

    def find_reservation(organization_id, reservation_id)
      validate_identifiers!(organization_id, reservation_id)
      QuotaReservation.includes(:meter_rate).find_by!(
        id: reservation_id,
        organization_id: organization_id
      )
    rescue ActiveRecord::RecordNotFound
      raise Invalid.new(reason_code: "usage_reservation_not_found"), cause: nil
    end
  end
end
