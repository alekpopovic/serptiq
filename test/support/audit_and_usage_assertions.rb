# frozen_string_literal: true

module TestSupport
  module AuditAndUsageAssertions
    def assert_audit_event(events:, type:, attributes: {})
      assert_recorded_event(events: events, type: type, attributes: attributes, label: "audit")
    end

    def assert_usage_event(events:, type:, units:, attributes: {})
      assert_recorded_event(
        events: events,
        type: type,
        attributes: attributes.merge(units: units),
        label: "usage"
      )
    end

    private

    def assert_recorded_event(events:, type:, attributes:, label:)
      matches = Array(events).select do |event|
        event_value(event, :type).to_s == type.to_s && attributes.all? do |key, expected|
          event_value(event, key) == expected
        end
      end
      assert_equal 1, matches.count,
        "expected exactly one #{label} event #{type.inspect} with #{attributes.inspect}"
      matches.first
    end

    def event_value(event, key)
      if event.respond_to?(:key?)
        return event[key] if event.key?(key)
        return event[key.to_s] if event.key?(key.to_s)
      end
      event.public_send(key)
    end
  end
end
