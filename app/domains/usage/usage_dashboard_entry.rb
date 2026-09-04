# frozen_string_literal: true

module Usage
  UsageDashboardEntry = Data.define(
    :pool_key, :unit, :state, :used, :reserved, :limit, :remaining,
    :starts_at, :reset_at, :meters, :reason_code
  ) do
    def initialize(**attributes)
      %i[pool_key unit state reason_code].each do |name|
        attributes[name] = attributes[name]&.to_s&.freeze
      end
      attributes[:meters] = attributes.fetch(:meters).freeze
      super(**attributes)
      freeze
    end

    def unlimited?
      state == "unlimited"
    end

    def disabled?
      state == "disabled"
    end

    def unavailable?
      state == "unavailable"
    end

    def temporarily_reserved?
      reserved.positive?
    end

    def exhausted?
      !unlimited? && !unavailable? && remaining&.zero?
    end
  end
end
