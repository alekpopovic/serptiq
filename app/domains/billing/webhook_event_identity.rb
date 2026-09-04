# frozen_string_literal: true

module Billing
  WebhookEventIdentity = Data.define(:provider, :reference, :event_type) do
    def initialize(provider:, reference:, event_type:)
      super(
        provider: ValueNormalization.string!(
          provider, name: "provider", maximum: 32, pattern: ValueNormalization::PROVIDER_PATTERN
        ),
        reference: ValueNormalization.string!(
          reference, name: "event reference", maximum: 191, pattern: ValueNormalization::REFERENCE_PATTERN
        ),
        event_type: ValueNormalization.string!(
          event_type, name: "event type", maximum: 64, pattern: ValueNormalization::KEY_PATTERN
        )
      )
      freeze
    end
  end
end
