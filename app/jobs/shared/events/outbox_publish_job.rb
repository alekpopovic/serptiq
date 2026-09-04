# frozen_string_literal: true

module Shared
  module Events
    class OutboxPublishJob < ApplicationJob
      runs_on :default
      system_authorization :outbox_publish,
        reason: "publishes a committed versioned domain event for downstream notification consumers"

      def perform(outbox_event_id:)
        Public.publish!(outbox_event_id: outbox_event_id)
      end
    end
  end
end
