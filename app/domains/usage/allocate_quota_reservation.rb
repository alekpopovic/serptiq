# frozen_string_literal: true

module Usage
  class AllocateQuotaReservation < ReservationMutation
    def initialize(clock: -> { Time.current }, pool: QuotaPool.new,
      idempotency: ReservationIdempotency.new, quantities: ReservationQuantity.new)
      initialize_support(clock: clock, pool: pool, idempotency: idempotency, quantities: quantities)
    end

    def call(organization_id:, reservation_id:, idempotency_key:, window:, meter_rate:,
      quantity:, at: @clock.call)
      now = validate_time!(at)
      reservation = find_reservation(organization_id, reservation_id)
      window, rate = validate_meter_context!(reservation, window, meter_rate, now)
      raw = @quantities.positive(quantity)
      billed = @quantities.billed(raw, weight: rate.weight)
      digest = @idempotency.digest(idempotency_key)
      checksum = @idempotency.checksum(
        organization_id: organization_id.to_s,
        reservation_id: reservation_id.to_s,
        usage_window_id: window.id,
        usage_meter_rate_id: rate.id,
        quantity: raw,
        billed_quantity: billed
      )
      existing = allocation_replay(organization_id, digest, checksum, reservation_id)
      return existing if existing

      with_locked_reservation(organization_id: organization_id, reservation_id: reservation_id) do |locked|
        existing = allocation_replay(organization_id, digest, checksum, reservation_id)
        next existing if existing

        ensure_held!(locked)
        raise Conflict.new(reason_code: "usage_reservation_expired") unless locked.expires_at > now

        allocated = QuotaAllocation.held.where(
          organization_id: organization_id,
          usage_quota_reservation_id: reservation_id
        ).sum(:billed_quantity)
        available = locked.held_quantity - locked.consumed_quantity - allocated
        additional = [ billed - available, BigDecimal("0") ].max
        if additional.positive?
          ensure_capacity!(reservation: locked, requested: additional, at: now)
          locked.update!(
            requested_quantity: locked.requested_quantity + additional,
            held_quantity: locked.held_quantity + additional
          )
          record_extension!(locked, digest, additional, now)
        end

        QuotaAllocation.create!(
          organization_id: organization_id,
          usage_quota_reservation_id: reservation_id,
          usage_window_id: window.id,
          usage_meter_definition_id: window.usage_meter_definition_id,
          usage_meter_rate_id: rate.id,
          idempotency_key_digest: digest,
          request_checksum: checksum,
          state: "held",
          quantity: raw,
          applied_weight: rate.weight,
          billed_quantity: billed,
          source_type: locked.source_type,
          source_id: locked.source_id,
          allocated_at: now
        )
      end
    rescue ActiveRecord::RecordNotUnique
      allocation_replay(organization_id, digest, checksum, reservation_id) || raise
    rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey => error
      raise Invalid.new(reason_code: "usage_quota_allocation_invalid"), cause: error
    rescue ActiveRecord::StatementInvalid => error
      translate_statement_error(error, reason_code: "usage_quota_allocation_invalid")
    end

    private

    def find_reservation(organization_id, reservation_id)
      validate_identifiers!(organization_id, reservation_id)
      QuotaReservation.includes(window: :meter_definition).find_by!(
        id: reservation_id, organization_id: organization_id
      )
    rescue ActiveRecord::RecordNotFound
      raise Invalid.new(reason_code: "usage_reservation_not_found"), cause: nil
    end

    def validate_meter_context!(reservation, supplied_window, supplied_rate, at)
      valid = supplied_window.is_a?(UsageWindow) && supplied_window.persisted? &&
        supplied_rate.is_a?(MeterRate) && supplied_rate.persisted?
      raise Invalid.new(reason_code: "usage_quota_allocation_context_invalid") unless valid

      window = UsageWindow.includes(:meter_definition).find_by(
        id: supplied_window.id,
        organization_id: reservation.organization_id,
        usage_meter_definition_id: supplied_window.usage_meter_definition_id
      )
      rate = MeterRate.find_by(
        id: supplied_rate.id,
        usage_meter_definition_id: supplied_window.usage_meter_definition_id
      )
      anchor = reservation.window.meter_definition
      target = window&.meter_definition
      same_pool = target && anchor &&
        target.pool_key == anchor.pool_key && target.billing_unit == anchor.billing_unit &&
        target.quota_entitlement_key == anchor.quota_entitlement_key &&
        target.window_policy == anchor.window_policy &&
        window.starts_at == reservation.window.starts_at && window.ends_at == reservation.window.ends_at
      raise Invalid.new(reason_code: "usage_quota_allocation_context_invalid") unless
        same_pool && rate && window.starts_at <= at && at < window.ends_at

      [ window, rate ]
    end

    def allocation_replay(organization_id, digest, checksum, reservation_id)
      allocation = QuotaAllocation.find_by(
        organization_id: organization_id,
        idempotency_key_digest: digest
      )
      return unless allocation
      return allocation if allocation.usage_quota_reservation_id.to_s == reservation_id.to_s &&
        allocation.request_checksum == checksum

      raise Conflict.new(reason_code: "usage_quota_allocation_idempotency_conflict")
    end

    def record_extension!(reservation, allocation_digest, quantity, at)
      raw_key = "quota-allocation-extension:#{allocation_digest}"
      digest, checksum = operation_identity(
        kind: "extend",
        organization_id: reservation.organization_id,
        reservation_id: reservation.id,
        idempotency_key: raw_key,
        attributes: { allocation_digest: allocation_digest, additional_quantity: quantity }
      )
      create_operation!(
        reservation: reservation,
        kind: "extend",
        digest: digest,
        checksum: checksum,
        quantity: quantity,
        at: at
      )
    end
  end
end
