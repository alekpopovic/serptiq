# frozen_string_literal: true

module Shared
  module Events
    class PublishOutboxEvent
      def initialize(clock: -> { Time.current })
        @clock = clock
      end

      def call(outbox_event_id:)
        OutboxEvent.transaction do
          event = OutboxEvent.lock.find(outbox_event_id)
          return event if event.published?

          attempted_at = @clock.call
          event.assign_attributes(
            attempt_count: event.attempt_count + 1,
            last_attempted_at: attempted_at,
            last_error_category: nil
          )
          ActiveSupport::Notifications.instrument(
            "outbox.searchops",
            event_id: event.id,
            event_type: event.event_type,
            event_version: event.event_version,
            organization_id: event.organization_id,
            aggregate_type: event.aggregate_type,
            aggregate_id: event.aggregate_id,
            payload: event.payload
          )
          event.published_at = attempted_at
          event.save!
          event
        end
      rescue ActiveRecord::RecordNotFound
        raise
      rescue StandardError
        record_failure(outbox_event_id)
        raise Shared::Public::TransientInfrastructureError.new(
          reason_code: "outbox_publish_failed"
        ), cause: nil
      end

      private

      def record_failure(outbox_event_id)
        OutboxEvent.transaction do
          event = OutboxEvent.lock.find(outbox_event_id)
          return if event.published?

          event.update!(
            attempt_count: event.attempt_count + 1,
            last_attempted_at: @clock.call,
            last_error_category: "delivery_failed"
          )
        end
      end
    end
  end
end
