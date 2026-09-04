# frozen_string_literal: true

module Usage
  class ReserveQuota < ReservationMutation
    MAXIMUM_INITIAL_TTL = 24.hours

    def initialize(clock: -> { Time.current }, pool: QuotaPool.new,
      idempotency: ReservationIdempotency.new, quantities: ReservationQuantity.new,
      limit_resolver: ReservationLimitResolver.new)
      initialize_support(clock: clock, pool: pool, idempotency: idempotency, quantities: quantities)
      @limit_resolver = limit_resolver
    end

    def call(window:, idempotency_key:, quantity:, source:, expires_at:, at: @clock.call)
      admitted_at = validate_time!(at)
      expiration = validate_time!(expires_at)
      window = validated_window(window, source, admitted_at, expiration)
      rate = effective_rate(window, admitted_at)
      requested = @quantities.billed(quantity, weight: rate.weight)
      digest = @idempotency.digest(idempotency_key)
      checksum = reservation_checksum(
        window: window,
        source: source,
        rate: rate,
        requested: requested,
        expires_at: expiration
      )
      existing = reservation_replay(window.organization_id, digest, checksum)
      return existing if existing

      QuotaReservation.transaction do
        @pool.lock!(window)
        existing = reservation_replay(window.organization_id, digest, checksum)
        return existing if existing

        snapshot = @limit_resolver.call(
          organization_id: window.organization_id,
          meter_definition: window.meter_definition,
          at: admitted_at
        )
        balance = @pool.balance(window: window, at: admitted_at)
        unless snapshot.unlimited? || balance.used + balance.reserved + requested <= snapshot.limit
          raise_quota_denial!(
            window: window,
            limit: snapshot.limit,
            balance: balance,
            requested: requested
          )
        end

        QuotaReservation.create!(reservation_attributes(
          window: window,
          source: source,
          rate: rate,
          digest: digest,
          checksum: checksum,
          requested: requested,
          snapshot: snapshot,
          admitted_at: admitted_at,
          expires_at: expiration
        ))
      end
    rescue ActiveRecord::RecordNotUnique
      reservation_replay(window.organization_id, digest, checksum) || raise
    rescue ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey,
      ActiveRecord::StatementInvalid => error
      translate_statement_error(error, reason_code: "usage_reservation_invalid") if
        error.is_a?(ActiveRecord::StatementInvalid)
      raise Invalid.new(reason_code: "usage_reservation_invalid"), cause: error
    end

    private

    def validated_window(window, source, admitted_at, expires_at)
      valid = window.is_a?(UsageWindow) && window.persisted? && source.is_a?(SourceReference) &&
        source.organization_id == window.organization_id.to_s && window.starts_at <= admitted_at &&
        admitted_at < window.ends_at && expires_at > admitted_at && expires_at <= window.ends_at &&
        expires_at <= admitted_at + MAXIMUM_INITIAL_TTL
      raise Invalid.new(reason_code: "usage_reservation_context_invalid") unless valid

      UsageWindow.includes(:meter_definition).find_by!(
        id: window.id,
        organization_id: window.organization_id,
        usage_meter_definition_id: window.usage_meter_definition_id
      )
    rescue ActiveRecord::RecordNotFound
      raise Invalid.new(reason_code: "usage_reservation_context_invalid"), cause: nil
    end

    def effective_rate(window, at)
      rate = MeterRate.effective_at(at).find_by(
        usage_meter_definition_id: window.usage_meter_definition_id
      )
      raise Invalid.new(reason_code: "usage_meter_rate_missing") unless rate

      rate
    end

    def reservation_checksum(window:, source:, rate:, requested:, expires_at:)
      @idempotency.checksum(
        organization_id: window.organization_id,
        window_id: window.id,
        meter_definition_id: window.usage_meter_definition_id,
        meter_rate_id: rate.id,
        requested_quantity: requested,
        source_type: source.type,
        source_id: source.id,
        expires_at: expires_at
      )
    end

    def reservation_replay(organization_id, digest, checksum)
      reservation = QuotaReservation.find_by(
        organization_id: organization_id,
        idempotency_key_digest: digest
      )
      return unless reservation
      return reservation if reservation.request_checksum == checksum

      raise Conflict.new(reason_code: "usage_reservation_idempotency_conflict")
    end

    def reservation_attributes(window:, source:, rate:, digest:, checksum:, requested:, snapshot:,
      admitted_at:, expires_at:)
      {
        organization_id: window.organization_id,
        source_organization_id: source.organization_id,
        usage_window_id: window.id,
        usage_meter_definition_id: window.usage_meter_definition_id,
        usage_meter_rate_id: rate.id,
        idempotency_key_digest: digest,
        request_checksum: checksum,
        state: "held",
        requested_quantity: requested,
        held_quantity: requested,
        consumed_quantity: 0,
        released_quantity: 0,
        source_type: source.type,
        source_id: source.id,
        limit_kind: snapshot.kind,
        limit_quantity: snapshot.limit,
        entitlement_key: snapshot.entitlement_key,
        entitlement_state: snapshot.entitlement_state,
        entitlement_provenance: snapshot.entitlement_provenance,
        entitlement_definition_checksum: snapshot.entitlement_definition_checksum,
        entitlement_override_id: snapshot.entitlement_override_id,
        subscription_id: snapshot.subscription_id,
        plan_version_id: snapshot.plan_version_id,
        subscription_revision: snapshot.subscription_revision,
        admitted_at: admitted_at,
        expires_at: expires_at
      }
    end
  end
end
