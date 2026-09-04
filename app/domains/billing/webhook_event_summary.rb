# frozen_string_literal: true

module Billing
  WebhookEventSummary = Data.define(
    :id, :provider, :event_type, :state, :received_at,
    :attempt_count, :duplicate_count, :conflict_count, :last_error_category
  ) do
    def initialize(**attributes)
      super(**attributes)
      freeze
    end
  end
end
