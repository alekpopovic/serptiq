# frozen_string_literal: true

module Usage
  class FindSourceEvent
    def call(organization_id:, source_type:, source_id:, event_id:)
      valid = Shared::Public.application_uuid?(organization_id) &&
        Shared::Public.application_uuid?(source_id) && SourceReference::TYPE_PATTERN.match?(source_type.to_s)
      raise Invalid.new(reason_code: "usage_source_event_unavailable") unless valid

      event = UsageEvent.find_by(
        id: event_id,
        organization_id: organization_id,
        source_type: source_type.to_s,
        source_id: source_id
      )
      raise Invalid.new(reason_code: "usage_source_event_unavailable") unless event

      event
    end
  end
end
