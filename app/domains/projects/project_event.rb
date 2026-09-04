# frozen_string_literal: true

module Projects
  module ProjectEvent
    module_function

    def record!(project:, event_type:, occurred_at:, actor_membership_id:)
      Shared::Public.record_outbox_event!(
        organization_id: project.organization_id,
        aggregate_type: "Project",
        aggregate_id: project.id,
        event_type: event_type,
        event_version: 1,
        payload: {
          "project_id" => project.id,
          "organization_id" => project.organization_id,
          "status" => project.status,
          "actor_membership_id" => actor_membership_id
        },
        idempotency_source: "#{event_type}:#{project.id}:#{project.lock_version}",
        occurred_at: occurred_at
      )
    end

    def enqueue(outbox_event)
      Shared::Public.enqueue_outbox_event!(outbox_event_id: outbox_event.id)
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "project.outbox_enqueue_failed")
    end
  end
end
