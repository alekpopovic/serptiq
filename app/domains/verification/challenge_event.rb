# frozen_string_literal: true

module Verification
  module ChallengeEvent
    module_function

    def record!(challenge:, event_type:, actor_membership_id:, occurred_at:)
      Shared::Public.record_outbox_event!(
        organization_id: challenge.organization_id,
        aggregate_type: "DomainVerification",
        aggregate_id: challenge.id,
        event_type: event_type,
        event_version: 1,
        payload: {
          "verification_id" => challenge.id,
          "project_id" => challenge.project_id,
          "property_id" => challenge.property_id,
          "environment_id" => challenge.environment_id,
          "method" => challenge.method,
          "state" => challenge.state,
          "failure_category" => challenge.failure_category,
          "actor_membership_id" => actor_membership_id
        }.compact,
        idempotency_source: "#{event_type}:#{challenge.id}:#{challenge.lock_version}",
        occurred_at: occurred_at
      )
    end

    def enqueue(event)
      Shared::Public.enqueue_outbox_event!(outbox_event_id: event.id)
    rescue StandardError => error
      Shared::Public.report_observability_failure(
        error, event_name: "verification.outbox_enqueue_failed"
      )
    end
  end
end
