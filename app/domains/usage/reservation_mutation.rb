# frozen_string_literal: true

module Usage
  class ReservationMutation
    private

    def initialize_support(clock:, pool:, idempotency:, quantities:)
      @clock = clock
      @pool = pool
      @idempotency = idempotency
      @quantities = quantities
    end

    def validate_time!(value, reason_code: "usage_reservation_time_invalid")
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

      raise Invalid.new(reason_code: reason_code)
    end

    def operation_identity(kind:, organization_id:, reservation_id:, idempotency_key:, attributes:)
      validate_identifiers!(organization_id, reservation_id)
      digest = @idempotency.digest(idempotency_key)
      checksum = @idempotency.checksum(
        attributes.merge(
          operation_kind: kind,
          organization_id: organization_id.to_s,
          reservation_id: reservation_id.to_s
        )
      )
      [ digest, checksum ]
    end

    def replay(organization_id:, reservation_id:, digest:, checksum:, kind:)
      operation = ReservationOperation.find_by(
        organization_id: organization_id,
        idempotency_key_digest: digest
      )
      return unless operation

      valid = operation.usage_quota_reservation_id.to_s == reservation_id.to_s &&
        operation.operation_kind == kind && operation.request_checksum == checksum
      raise Conflict.new(reason_code: "usage_reservation_idempotency_conflict") unless valid

      QuotaReservation.find_by!(id: reservation_id, organization_id: organization_id)
    end

    def with_locked_reservation(organization_id:, reservation_id:)
      QuotaReservation.transaction do
        reservation = QuotaReservation.includes(window: :meter_definition).find_by(
          id: reservation_id,
          organization_id: organization_id
        )
        raise Invalid.new(reason_code: "usage_reservation_not_found") unless reservation

        @pool.lock!(reservation.window)
        reservation = QuotaReservation.lock.includes(window: :meter_definition).find_by!(
          id: reservation_id,
          organization_id: organization_id
        )
        yield reservation
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey => error
      raise Invalid.new(reason_code: "usage_reservation_transition_invalid"), cause: error
    end

    def ensure_held!(reservation)
      raise Conflict.new(reason_code: "usage_reservation_not_held") unless reservation.held?
    end

    def ensure_capacity!(reservation:, requested:, at:, balance: nil)
      return if reservation.unlimited?

      current = balance || @pool.balance(window: reservation.window, at: at)
      return if current.used + current.reserved + requested <= reservation.limit_quantity

      raise_quota_denial!(
        window: reservation.window,
        limit: reservation.limit_quantity,
        balance: current,
        requested: requested
      )
    end

    def raise_quota_denial!(window:, limit:, balance:, requested:)
      definition = window.meter_definition
      denial = QuotaDenial.new(
        organization_id: window.organization_id,
        window_id: window.id,
        meter_key: definition.key,
        pool_key: definition.pool_key,
        unit: definition.billing_unit,
        limit: limit,
        used: balance.used,
        reserved: balance.reserved,
        requested: requested,
        reset_at: window.ends_at,
        reason_code: "usage_quota_exceeded"
      )
      raise QuotaExceeded.new(denial: denial)
    end

    def create_operation!(reservation:, kind:, digest:, checksum:, quantity:, requested_expires_at: nil,
      usage_event_id: nil, at: @clock.call)
      ReservationOperation.create!(
        organization_id: reservation.organization_id,
        usage_quota_reservation_id: reservation.id,
        operation_kind: kind,
        idempotency_key_digest: digest,
        request_checksum: checksum,
        quantity: quantity,
        requested_expires_at: requested_expires_at,
        usage_event_id: usage_event_id,
        created_at: at
      )
    end

    def validate_identifiers!(organization_id, reservation_id)
      return if Shared::Public.application_uuid?(organization_id) &&
        Shared::Public.application_uuid?(reservation_id)

      raise Invalid.new(reason_code: "usage_reservation_not_found")
    end

    def translate_statement_error(error, reason_code:)
      raise error if error.is_a?(ActiveRecord::Deadlocked) ||
        error.is_a?(ActiveRecord::LockWaitTimeout)

      raise Invalid.new(reason_code: reason_code), cause: error
    end
  end
end
