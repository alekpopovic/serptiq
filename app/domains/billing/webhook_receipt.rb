# frozen_string_literal: true

module Billing
  WebhookReceipt = Data.define(:id, :status, :event_type) do
    STATUSES = %w[accepted duplicate conflict].freeze

    def initialize(id:, status:, event_type:)
      normalized_status = status.to_s
      raise ArgumentError, "webhook receipt status is invalid" unless STATUSES.include?(normalized_status)

      super(
        id: ValueNormalization.uuid!(id, name: "webhook event"),
        status: normalized_status.freeze,
        event_type: ValueNormalization.string!(
          event_type, name: "webhook event type", maximum: 64,
          pattern: ValueNormalization::KEY_PATTERN
        )
      )
      freeze
    end
  end
end
