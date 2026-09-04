# frozen_string_literal: true

module Billing
  Customer = Data.define(:provider, :reference, :organization_id, :email, :created_at, :metadata) do
    def initialize(provider:, reference:, organization_id:, created_at:, email: nil, metadata: {})
      super(
        provider: ValueNormalization.string!(
          provider, name: "provider", maximum: 32, pattern: ValueNormalization::PROVIDER_PATTERN
        ),
        reference: ValueNormalization.string!(
          reference, name: "customer reference", maximum: 191,
          pattern: ValueNormalization::REFERENCE_PATTERN
        ),
        organization_id: ValueNormalization.uuid!(organization_id, name: "organization"),
        email: ValueNormalization.optional_string(
          email, name: "email", maximum: 320, pattern: ValueNormalization::EMAIL_PATTERN
        ),
        created_at: ValueNormalization.time!(created_at, name: "customer creation time"),
        metadata: ValueNormalization.metadata(metadata)
      )
      freeze
    end

    def as_json(*)
      {
        provider: provider,
        organization_id: organization_id,
        reference: ValueNormalization::FILTERED,
        email: ValueNormalization.redacted(email),
        created_at: created_at
      }.compact.freeze
    end

    def inspect
      ValueNormalization.safe_inspect(self)
    end
  end
end
