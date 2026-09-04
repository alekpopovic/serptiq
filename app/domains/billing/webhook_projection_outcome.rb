# frozen_string_literal: true

module Billing
  WebhookProjectionOutcome = Data.define(:result, :organization_id, :subscription_id, :canonical_changed) do
    def initialize(result:, organization_id: nil, subscription_id: nil, canonical_changed: false)
      normalized = result.to_s
      raise ArgumentError, "projection result is invalid" unless self.class::RESULTS.include?(normalized)
      raise ArgumentError, "canonical change flag is invalid" unless [ true, false ].include?(canonical_changed)

      super(
        result: normalized.freeze,
        organization_id: normalize_uuid(organization_id, "organization"),
        subscription_id: normalize_uuid(subscription_id, "subscription"),
        canonical_changed: canonical_changed
      )
      freeze
    end

    private

    def normalize_uuid(value, name)
      return if value.nil?

      ValueNormalization.uuid!(value, name: name)
    end
  end
  WebhookProjectionOutcome::RESULTS = %w[applied stale observed ignored].freeze
end
