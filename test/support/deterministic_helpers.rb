# frozen_string_literal: true

require "digest"

module TestSupport
  module DeterministicHelpers
    FIXED_TIME = Time.utc(2026, 1, 15, 12, 0, 0).freeze

    def at_fixed_time(time = FIXED_TIME, &block)
      travel_to(time, &block)
    end

    def deterministic_uuid(namespace, value)
      hex = Digest::SHA256.hexdigest("#{namespace}:#{value}").first(32)
      hex[12] = "5"
      hex[16] = ((hex[16].to_i(16) & 0x3) | 0x8).to_s(16)
      [ hex[0, 8], hex[8, 4], hex[12, 4], hex[16, 4], hex[20, 12] ].join("-")
    end
  end
end
