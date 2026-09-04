# frozen_string_literal: true

module Billing
  VerifiedWebhook = Data.define(:provider, :raw_body, :received_at) do
    MAX_BODY_BYTES = 524_288

    def initialize(provider:, raw_body:, received_at:)
      body = raw_body.to_s
      raise ArgumentError, "webhook body is invalid" unless body.bytesize.between?(1, MAX_BODY_BYTES)

      super(
        provider: ValueNormalization.string!(
          provider, name: "provider", maximum: 32, pattern: ValueNormalization::PROVIDER_PATTERN
        ),
        raw_body: body.dup.freeze,
        received_at: ValueNormalization.time!(received_at, name: "webhook receive time")
      )
      freeze
    end

    def as_json(*)
      { provider: provider, raw_body: ValueNormalization::FILTERED, bytes: raw_body.bytesize,
        received_at: received_at }.freeze
    end

    def inspect
      ValueNormalization.safe_inspect(self)
    end
  end
end
