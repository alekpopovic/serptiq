# frozen_string_literal: true

module Usage
  BillingPeriod = Data.define(:starts_at, :ends_at, :time_zone_name, :reference) do
    def initialize(starts_at:, ends_at:, time_zone_name:, reference:)
      zone = time_zone_name.to_s
      opaque_reference = reference.to_s
      valid_zone = ActiveSupport::TimeZone[zone] || ActiveSupport::TimeZone.all.find { |item| item.tzinfo.name == zone }
      valid_times = time_value?(starts_at) && time_value?(ends_at) && ends_at > starts_at
      valid_reference = opaque_reference.bytesize.between?(1, 160) && opaque_reference.valid_encoding?
      raise Invalid.new(reason_code: "usage_billing_period_invalid") unless
        valid_zone && valid_times && valid_reference

      super(
        starts_at: starts_at.utc.freeze,
        ends_at: ends_at.utc.freeze,
        time_zone_name: zone.freeze,
        reference: opaque_reference.freeze
      )
      freeze
    end

    def cover?(time)
      starts_at <= time && time < ends_at
    end

    private

    def time_value?(value)
      value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
    end
  end
end
