# frozen_string_literal: true

require "digest"

module Shared
  module Events
    class RecordOutboxEvent
      def initialize(clock: -> { Time.current })
        @clock = clock
      end

      def call(organization_id:, aggregate_type:, aggregate_id:, event_type:, payload:, idempotency_source:,
        event_version: 1, occurred_at: @clock.call)
        source = idempotency_source.to_s
        raise ArgumentError, "outbox idempotency source is invalid" unless source.bytesize.between?(1, 500)

        OutboxEvent.create_or_find_by!(idempotency_key: Digest::SHA256.hexdigest(source)) do |event|
          event.assign_attributes(
            organization_id: organization_id,
            aggregate_type: aggregate_type,
            aggregate_id: aggregate_id,
            event_type: event_type,
            event_version: event_version,
            payload: payload,
            occurred_at: occurred_at
          )
        end
      end
    end
  end
end
