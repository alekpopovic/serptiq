# frozen_string_literal: true

module Usage
  class RecordCorrection
    def initialize(clock: -> { Time.current }, recorder: nil)
      @clock = clock
      @recorder = recorder || RecordEvent.new(clock: clock)
    end

    def call(organization_id:, event_id:, idempotency_key:, quantity:, reason_code:,
      occurred_at: @clock.call, actor_membership_id: nil, metadata: {})
      UsageEvent.transaction do
        original = UsageEvent.lock.find_by(id: event_id, organization_id: organization_id)
        raise Invalid.new(reason_code: "usage_correction_target_invalid") unless
          original && original.event_kind != "correction"

        @recorder.call(
          window: original.window,
          idempotency_key: idempotency_key,
          quantity: quantity,
          source: SourceReference.new(
            organization_id: original.source_organization_id,
            type: original.source_type,
            id: original.source_id
          ),
          occurred_at: occurred_at,
          metadata: metadata,
          event_kind: "correction",
          meter_rate: original.meter_rate,
          correction_of_event_id: original.id,
          actor_membership_id: actor_membership_id,
          reason_code: reason_code
        )
      end
    rescue Invalid => error
      raise unless error.reason_code == "usage_event_invalid"

      raise Invalid.new(reason_code: "usage_correction_invalid"), cause: error
    rescue ActiveRecord::StatementInvalid => error
      raise Invalid.new(reason_code: "usage_correction_invalid"), cause: error
    end
  end
end
