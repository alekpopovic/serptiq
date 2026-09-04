# frozen_string_literal: true

module Usage
  UsageSummary = Data.define(
    :organization_id, :window_id, :meter_key, :pool_key, :unit,
    :used, :reserved, :limit, :remaining, :unlimited, :starts_at, :ends_at
  ) do
    def initialize(**attributes)
      %i[organization_id window_id meter_key pool_key unit].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      super(**attributes)
      freeze
    end

    def unlimited?
      unlimited
    end
  end
end
