# frozen_string_literal: true

module Verification
  module FreshnessPolicy
    MAX_AGES = {
      "standard" => 30.days,
      "high_volume" => 7.days,
      "render" => 24.hours
    }.freeze

    module_function

    def fresh?(challenge:, workload:, at: Time.current)
      maximum_age = MAX_AGES.fetch(workload.to_s) do
        raise ArgumentError, "unknown verification workload"
      end
      challenge.verified? && challenge.verified_at.present? && challenge.expires_at > at &&
        challenge.verified_at >= at - maximum_age
    end
  end
end
