# frozen_string_literal: true

module Usage
  class SourceAggregateQuery
    def call(organization_id:, source_type:, source_id:)
      valid = Shared::Public.application_uuid?(organization_id) &&
        Shared::Public.application_uuid?(source_id) && SourceReference::TYPE_PATTERN.match?(source_type.to_s)
      raise Invalid.new(reason_code: "usage_source_aggregate_invalid") unless valid

      UsageEvent.joins(:meter_definition).where(
        organization_id: organization_id,
        source_type: source_type.to_s,
        source_id: source_id
      ).group("usage_meter_definitions.key").sum(:billed_quantity).transform_keys(&:to_s).freeze
    end
  end
end
