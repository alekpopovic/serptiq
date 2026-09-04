# frozen_string_literal: true

module Billing
  InvoiceTransactionLink = Data.define(:provider, :kind, :reference, :url, :issued_at) do
    KINDS = %w[invoice transaction].freeze

    def initialize(provider:, kind:, reference:, url:, issued_at:)
      kind = kind.to_s
      raise ArgumentError, "billing document kind is invalid" unless KINDS.include?(kind)

      super(
        provider: ValueNormalization.string!(
          provider, name: "provider", maximum: 32, pattern: ValueNormalization::PROVIDER_PATTERN
        ),
        kind: kind.freeze,
        reference: ValueNormalization.string!(
          reference, name: "billing document reference", maximum: 191,
          pattern: ValueNormalization::REFERENCE_PATTERN
        ),
        url: ValueNormalization.url!(url, name: "billing document URL"),
        issued_at: ValueNormalization.time!(issued_at, name: "billing document issue time")
      )
      freeze
    end

    def as_json(*)
      {
        provider: provider,
        kind: kind,
        reference: ValueNormalization::FILTERED,
        url: ValueNormalization::FILTERED,
        issued_at: issued_at
      }.freeze
    end

    def inspect
      ValueNormalization.safe_inspect(self)
    end
  end
end
