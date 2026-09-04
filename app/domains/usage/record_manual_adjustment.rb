# frozen_string_literal: true

module Usage
  class RecordManualAdjustment
    def initialize(authorizer: ManualAdjustmentAuthorizer.new, recorder: RecordEvent.new)
      @authorizer = authorizer
      @recorder = recorder
    end

    def call(window:, idempotency_key:, quantity:, source:, actor_membership:, authorization:,
      reason_code:, occurred_at: Time.current, metadata: {})
      @authorizer.call(
        organization_id: window.organization_id,
        actor_membership: actor_membership,
        authorization: authorization
      )
      @recorder.call(
        window: window,
        idempotency_key: idempotency_key,
        quantity: quantity,
        source: source,
        occurred_at: occurred_at,
        metadata: metadata,
        event_kind: "manual_adjustment",
        actor_membership_id: actor_membership.id,
        reason_code: reason_code
      )
    end
  end
end
