# frozen_string_literal: true

module Properties
  module PropertyEvent
    module_function

    def record!(property:, event_type:, occurred_at:, actor_membership_id:)
      Shared::Public.record_outbox_event!(
        organization_id: property.organization_id,
        aggregate_type: "Property",
        aggregate_id: property.id,
        event_type: event_type,
        event_version: 1,
        payload: {
          "property_id" => property.id,
          "project_id" => property.project_id,
          "organization_id" => property.organization_id,
          "kind" => property.kind,
          "status" => property.status,
          "verification_status" => property.verification_status,
          "actor_membership_id" => actor_membership_id
        },
        idempotency_source: "#{event_type}:#{property.id}:#{property.lock_version}",
        occurred_at: occurred_at
      )
    end

    def enqueue(outbox_event)
      Shared::Public.enqueue_outbox_event!(outbox_event_id: outbox_event.id)
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "property.outbox_enqueue_failed")
    end
  end
end
