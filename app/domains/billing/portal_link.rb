# frozen_string_literal: true

module Billing
  PortalLink = Data.define(:provider, :url, :created_at, :expires_at) do
    def initialize(provider:, url:, created_at:, expires_at:)
      created = ValueNormalization.time!(created_at, name: "portal link creation time")
      expiration = ValueNormalization.time!(expires_at, name: "portal link expiration time")
      raise ArgumentError, "portal link expiration must follow creation" unless expiration > created

      super(
        provider: ValueNormalization.string!(
          provider, name: "provider", maximum: 32, pattern: ValueNormalization::PROVIDER_PATTERN
        ),
        url: ValueNormalization.url!(url, name: "portal URL"),
        created_at: created,
        expires_at: expiration
      )
      freeze
    end

    def as_json(*)
      {
        provider: provider,
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
