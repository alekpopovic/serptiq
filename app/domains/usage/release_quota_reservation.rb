# frozen_string_literal: true

module Usage
  class ReleaseQuotaReservation < ReservationMutation
    def initialize(clock: -> { Time.current }, pool: QuotaPool.new,
      idempotency: ReservationIdempotency.new, quantities: ReservationQuantity.new)
      initialize_support(clock: clock, pool: pool, idempotency: idempotency, quantities: quantities)
    end

    def call(organization_id:, reservation_id:, idempotency_key:, at: @clock.call)
      now = validate_time!(at)
      digest, checksum = operation_identity(
        kind: "release",
        organization_id: organization_id,
        reservation_id: reservation_id,
        idempotency_key: idempotency_key,
        attributes: {}
      )
      existing = replay(
        organization_id: organization_id,
        reservation_id: reservation_id,
        digest: digest,
        checksum: checksum,
        kind: "release"
      )
      return existing if existing

      with_locked_reservation(organization_id: organization_id, reservation_id: reservation_id) do |locked|
        existing = replay(
          organization_id: organization_id,
          reservation_id: reservation_id,
          digest: digest,
          checksum: checksum,
          kind: "release"
        )
        next existing if existing

        ensure_held!(locked)
        if QuotaAllocation.held.where(
          organization_id: organization_id,
          usage_quota_reservation_id: reservation_id
        ).exists?
          raise Conflict.new(reason_code: "usage_reservation_allocations_pending")
        end
        locked.update!(
          released_quantity: locked.held_quantity,
          released_at: now,
          state: "released"
        )
        create_operation!(
          reservation: locked,
          kind: "release",
          digest: digest,
          checksum: checksum,
          quantity: locked.held_quantity,
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
        kind: "release"
      ) || raise
    rescue ActiveRecord::StatementInvalid => error
      translate_statement_error(error, reason_code: "usage_reservation_release_invalid")
    end
  end
end
