# frozen_string_literal: true

module Usage
  QuotaDenial = Data.define(
    :organization_id, :window_id, :meter_key, :pool_key, :unit,
    :limit, :used, :reserved, :requested, :reset_at, :reason_code
  ) do
    def initialize(**attributes)
      %i[organization_id window_id meter_key pool_key unit reason_code].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      super(**attributes)
      freeze
    end

    def as_json(*)
      {
        meter: meter_key,
        pool: pool_key,
        unit: unit,
        limit: limit,
        used: used,
        reserved: reserved,
        requested: requested,
        reset_at: reset_at,
        reason_code: reason_code
      }
    end
  end
end
