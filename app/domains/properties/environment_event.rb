# frozen_string_literal: true

module Properties
  module EnvironmentEvent
    module_function

    def record!(environment:, event_type:, occurred_at:, actor_membership_id:)
      Shared::Public.record_outbox_event!(
        organization_id: environment.organization_id,
        aggregate_type: "PropertyEnvironment",
        aggregate_id: environment.id,
        event_type: event_type,
        event_version: 1,
        payload: {
          "environment_id" => environment.id,
          "property_id" => environment.property_id,
          "project_id" => environment.project_id,
          "organization_id" => environment.organization_id,
          "kind" => environment.kind,
          "status" => environment.status,
          "primary" => environment.primary?,
          "actor_membership_id" => actor_membership_id
        },
        idempotency_source: "#{event_type}:#{environment.id}:#{environment.lock_version}",
        occurred_at: occurred_at
      )
    end

    def enqueue(event)
      Shared::Public.enqueue_outbox_event!(outbox_event_id: event.id)
    rescue StandardError => error
      Shared::Public.report_observability_failure(
        error, event_name: "property_environment.outbox_enqueue_failed"
      )
    end
  end
end
