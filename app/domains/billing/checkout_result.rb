# frozen_string_literal: true

module Billing
  CheckoutResult = Data.define(:provider, :reference, :url, :created_at, :expires_at) do
    def initialize(provider:, reference:, url:, created_at:, expires_at:)
      created = ValueNormalization.time!(created_at, name: "checkout creation time")
      expiration = ValueNormalization.time!(expires_at, name: "checkout expiration time")
      raise ArgumentError, "checkout expiration must follow creation" unless expiration > created

      super(
        provider: ValueNormalization.string!(
          provider, name: "provider", maximum: 32, pattern: ValueNormalization::PROVIDER_PATTERN
        ),
        reference: ValueNormalization.string!(
          reference, name: "checkout reference", maximum: 191,
          pattern: ValueNormalization::REFERENCE_PATTERN
        ),
        url: ValueNormalization.url!(url, name: "checkout URL"),
        created_at: created,
        expires_at: expiration
      )
      freeze
    end

    def as_json(*)
      {
        provider: provider,
        reference: ValueNormalization::FILTERED,
        url: ValueNormalization::FILTERED,
        created_at: created_at,
        expires_at: expires_at
      }.freeze
    end

    def inspect
      ValueNormalization.safe_inspect(self)
    end
  end
end
