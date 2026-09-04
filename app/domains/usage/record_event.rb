# frozen_string_literal: true

require "digest"
require "json"

module Usage
  class RecordEvent
    IDEMPOTENCY_MAX_BYTES = 200

    def initialize(clock: -> { Time.current }, quantity: Quantity.new, metadata: Metadata.new)
      @clock = clock
      @quantity = quantity
      @metadata = metadata
    end

    def call(window:, idempotency_key:, quantity:, source:, occurred_at:, metadata: {},
      event_kind: "usage", meter_rate: nil, correction_of_event_id: nil,
      actor_membership_id: nil, reason_code: nil)
      validate_context!(window, source, occurred_at, idempotency_key)
      normalized_quantity = @quantity.call(quantity, positive: event_kind == "usage")
      normalized_metadata = @metadata.call(metadata)
      rate = resolve_rate(window, occurred_at, meter_rate)
      attributes = event_attributes(
        window: window, idempotency_key: idempotency_key, quantity: normalized_quantity,
        source: source, occurred_at: occurred_at, metadata: normalized_metadata,
        event_kind: event_kind, meter_rate: rate, correction_of_event_id: correction_of_event_id,
        actor_membership_id: actor_membership_id, reason_code: reason_code
      )
      attributes[:request_checksum] = request_checksum(attributes.except(:recorded_at))
      existing = UsageEvent.find_by(
        organization_id: window.organization_id,
        idempotency_key_digest: attributes[:idempotency_key_digest]
      )
      return verify_duplicate!(existing, attributes[:request_checksum]) if existing

      persist(attributes)
    end

    private

    def validate_context!(window, source, occurred_at, idempotency_key)
      valid_time = occurred_at.is_a?(Time) || occurred_at.is_a?(ActiveSupport::TimeWithZone)
      key = idempotency_key.to_s
      raise Invalid.new(reason_code: "usage_event_context_invalid") unless
        window.is_a?(UsageWindow) && window.persisted? && source.is_a?(SourceReference) &&
          source.organization_id == window.organization_id.to_s && valid_time &&
          key.valid_encoding? && key.bytesize.between?(1, IDEMPOTENCY_MAX_BYTES)
    end

    def resolve_rate(window, occurred_at, supplied)
      rate = supplied || MeterRate.effective_at(occurred_at).find_by(
        usage_meter_definition_id: window.usage_meter_definition_id
      )
      raise Invalid.new(reason_code: "usage_meter_rate_missing") unless
        rate && rate.usage_meter_definition_id == window.usage_meter_definition_id

      rate
    end

    def event_attributes(window:, idempotency_key:, quantity:, source:, occurred_at:, metadata:,
      event_kind:, meter_rate:, correction_of_event_id:, actor_membership_id:, reason_code:)
      weight = BigDecimal(meter_rate.weight.to_s)
      billed = quantity * weight
      @quantity.call(billed)
      {
        organization_id: window.organization_id,
        source_organization_id: source.organization_id,
        usage_window_id: window.id,
        usage_meter_definition_id: window.usage_meter_definition_id,
        usage_meter_rate_id: meter_rate.id,
        idempotency_key_digest: Digest::SHA256.hexdigest(idempotency_key.to_s),
        event_kind: event_kind.to_s,
        quantity: quantity,
        applied_weight: weight,
        billed_quantity: billed,
        source_type: source.type,
        source_id: source.id,
        correction_of_event_id: correction_of_event_id,
        actor_membership_id: actor_membership_id,
        reason_code: reason_code&.to_s,
        metadata: metadata,
        occurred_at: occurred_at,
        recorded_at: @clock.call
      }
    end

    def request_checksum(attributes)
      normalized = attributes.transform_values do |value|
        case value
        when BigDecimal then value.to_s("F")
        when Time, ActiveSupport::TimeWithZone then value.utc.iso8601(6)
        when Hash then canonical_hash(value)
        else value
        end
      end
      Digest::SHA256.hexdigest(JSON.generate(normalized.sort.to_h))
    end

    def canonical_hash(value)
      value.sort.to_h.transform_values do |item|
        item.is_a?(Hash) ? canonical_hash(item) : item
      end
    end

    def persist(attributes)
      UsageEvent.transaction(requires_new: true) do
        event = UsageEvent.create!(attributes)
        audit_manual_adjustment(event) if event.event_kind == "manual_adjustment"
        event
      end
    rescue ActiveRecord::RecordNotUnique
      existing = UsageEvent.find_by!(
        organization_id: attributes.fetch(:organization_id),
        idempotency_key_digest: attributes.fetch(:idempotency_key_digest)
      )
      verify_duplicate!(existing, attributes.fetch(:request_checksum))
    rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordInvalid => error
      raise Invalid.new(reason_code: "usage_event_invalid"), cause: error
    end

    def verify_duplicate!(existing, expected_checksum)
      return existing if existing.request_checksum == expected_checksum

      raise Conflict.new(reason_code: "usage_idempotency_conflict")
    end

    def audit_manual_adjustment(event)
      Auditing::Public.record!(
        organization_id: event.organization_id,
        actor_membership_id: event.actor_membership_id,
        action: "usage.manual_adjusted",
        target_type: "UsageWindow",
        target_id: event.usage_window_id,
        result: "succeeded",
        metadata: {
          operation: "manual_adjustment",
          meter: event.meter_definition.key,
          reason_code: event.reason_code
        },
        occurred_at: event.recorded_at
      )
    end
  end
end
