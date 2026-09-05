# frozen_string_literal: true

module Usage
  class ExpireQuotaReservations < ReservationMutation
    BATCH_SIZE = 500
    MAX_BATCHES = 20

    def initialize(clock: -> { Time.current }, pool: QuotaPool.new,
      idempotency: ReservationIdempotency.new, quantities: ReservationQuantity.new)
      initialize_support(clock: clock, pool: pool, idempotency: idempotency, quantities: quantities)
    end

    def call(at: @clock.call)
      cutoff = validate_time!(at)
      expired = 0
      MAX_BATCHES.times do
        ids = QuotaReservation.stale_at(cutoff).order(:expires_at, :id).limit(BATCH_SIZE).pluck(:id)
        break if ids.empty?

        ids.each { |id| expired += 1 if expire_one(id, cutoff) }
      end
      expired
    end

    private

    def expire_one(reservation_id, cutoff)
      QuotaReservation.transaction do
        reservation = QuotaReservation.includes(window: :meter_definition).find_by(id: reservation_id)
        next false unless reservation

        @pool.lock!(reservation.window)
        reservation = QuotaReservation.lock.find_by(id: reservation_id)
        next false unless reservation&.held? && reservation.expires_at <= cutoff

        raw_key = "quota-expire:#{reservation.id}:#{reservation.expires_at.utc.iso8601(6)}"
        digest, checksum = operation_identity(
          kind: "expire",
          organization_id: reservation.organization_id,
          reservation_id: reservation.id,
          idempotency_key: raw_key,
          attributes: { expires_at: reservation.expires_at }
        )
        existing = replay(
          organization_id: reservation.organization_id,
          reservation_id: reservation.id,
          digest: digest,
          checksum: checksum,
          kind: "expire"
        )
        next false if existing

        release_allocations!(reservation, cutoff)
        released = reservation.held_quantity - reservation.consumed_quantity
        reservation.update!(
          released_quantity: released,
          expired_at: cutoff,
          state: "expired"
        )
        create_operation!(
          reservation: reservation,
          kind: "expire",
          digest: digest,
          checksum: checksum,
          quantity: released,
          requested_expires_at: reservation.expires_at,
          at: cutoff
        )
        true
      end
    end

    def release_allocations!(reservation, cutoff)
      reservation.allocations.held.lock.order(:id).each do |allocation|
        raw_key = "quota-allocation-expire:#{allocation.id}:#{reservation.expires_at.utc.iso8601(6)}"
        digest = @idempotency.digest(raw_key)
        checksum = @idempotency.checksum(
          organization_id: reservation.organization_id.to_s,
          allocation_id: allocation.id.to_s,
          disposition: "release",
          occurred_at: cutoff,
          metadata: { "reason" => "reservation_expired" }
        )
        allocation.update!(
          state: "released",
          completion_key_digest: digest,
          completion_checksum: checksum,
          completed_at: cutoff
        )
      end
    end
  end
end
