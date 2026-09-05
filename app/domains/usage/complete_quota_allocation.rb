# frozen_string_literal: true

module Usage
  class CompleteQuotaAllocation < ReservationMutation
    def initialize(clock: -> { Time.current }, pool: QuotaPool.new,
      idempotency: ReservationIdempotency.new, quantities: ReservationQuantity.new,
      recorder: nil)
      initialize_support(clock: clock, pool: pool, idempotency: idempotency, quantities: quantities)
      @recorder = recorder || RecordEvent.new(clock: clock)
    end

    def call(organization_id:, allocation_id:, idempotency_key:, disposition:,
      occurred_at: @clock.call, at: @clock.call, metadata: {})
      now = validate_time!(at)
      occurred = validate_time!(occurred_at, reason_code: "usage_allocation_occurrence_invalid")
      action = disposition.to_s
      raise Invalid.new(reason_code: "usage_quota_allocation_disposition_invalid") unless
        action.in?(%w[consume release])

      allocation = find_allocation(organization_id, allocation_id)
      normalized_metadata = Metadata.new.call(metadata)
      validate_occurrence!(allocation, occurred, now, action)
      digest = @idempotency.digest(idempotency_key)
      checksum = @idempotency.checksum(
        organization_id: organization_id.to_s,
        allocation_id: allocation_id.to_s,
        disposition: action,
        occurred_at: occurred,
        metadata: normalized_metadata
      )
      replay = completion_replay(allocation, digest, checksum, action)
      return replay if replay

      with_locked_reservation(
        organization_id: organization_id,
        reservation_id: allocation.usage_quota_reservation_id
      ) do |reservation|
        locked = QuotaAllocation.lock.includes(:window, :meter_rate).find_by!(
          id: allocation_id,
          organization_id: organization_id,
          usage_quota_reservation_id: reservation.id
        )
        replay = completion_replay(locked, digest, checksum, action)
        next replay if replay

        raise Conflict.new(reason_code: "usage_quota_allocation_not_held") unless locked.held?
        if action == "consume"
          ensure_held!(reservation)
          raise Conflict.new(reason_code: "usage_reservation_expired") unless reservation.expires_at > now
          event = record_usage(locked, digest, occurred, normalized_metadata)
          reservation.update!(consumed_quantity: reservation.consumed_quantity + locked.billed_quantity)
          locked.update!(
            state: "consumed",
            completion_key_digest: digest,
            completion_checksum: checksum,
            usage_event_id: event.id,
            completed_at: now
          )
        else
          locked.update!(
            state: "released",
            completion_key_digest: digest,
            completion_checksum: checksum,
            completed_at: now
          )
        end
        locked
      end
    rescue ActiveRecord::RecordNotFound
      raise Invalid.new(reason_code: "usage_quota_allocation_not_found"), cause: nil
    rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey => error
      raise Invalid.new(reason_code: "usage_quota_allocation_transition_invalid"), cause: error
    rescue ActiveRecord::StatementInvalid => error
      translate_statement_error(error, reason_code: "usage_quota_allocation_transition_invalid")
    end

    private

    def find_allocation(organization_id, allocation_id)
      unless Shared::Public.application_uuid?(organization_id) &&
          Shared::Public.application_uuid?(allocation_id)
        raise Invalid.new(reason_code: "usage_quota_allocation_not_found")
      end

      QuotaAllocation.includes(:reservation, :window, :meter_rate).find_by!(
        id: allocation_id, organization_id: organization_id
      )
    rescue ActiveRecord::RecordNotFound
      raise Invalid.new(reason_code: "usage_quota_allocation_not_found"), cause: nil
    end

    def validate_occurrence!(allocation, occurred, now, action)
      valid = occurred <= now
      valid &&= allocation.window.starts_at <= occurred && occurred < allocation.window.ends_at if
        action == "consume"
      raise Invalid.new(reason_code: "usage_allocation_occurrence_invalid") unless valid
    end

    def completion_replay(allocation, digest, checksum, action)
      return unless allocation.completion_key_digest
      return allocation if allocation.completion_key_digest == digest &&
        allocation.completion_checksum == checksum &&
        ((action == "consume" && allocation.consumed?) ||
          (action == "release" && allocation.released?))

      raise Conflict.new(reason_code: "usage_quota_allocation_idempotency_conflict")
    end

    def record_usage(allocation, operation_digest, occurred_at, metadata)
      @recorder.call(
        window: allocation.window,
        idempotency_key: "quota-allocation-consume:#{allocation.id}:#{operation_digest}",
        quantity: allocation.quantity,
        source: SourceReference.new(
          organization_id: allocation.organization_id,
          type: allocation.source_type,
          id: allocation.source_id
        ),
        occurred_at: occurred_at,
        metadata: metadata,
        meter_rate: allocation.meter_rate
      )
    end
  end
end
