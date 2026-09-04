# frozen_string_literal: true

module Verification
  module FreshnessPolicy
    MAX_AGES = {
      "standard" => 30.days,
      "high_volume" => 7.days,
      "render" => 24.hours
    }.freeze
    DNS_RECHECK_INTERVAL = MAX_AGES.fetch("high_volume")
    DNS_RECHECK_RETRY_INTERVAL = 6.hours

    module_function

    def fresh?(challenge:, workload:, at: Time.current)
      maximum_age = MAX_AGES.fetch(workload.to_s) do
        raise ArgumentError, "unknown verification workload"
      end
      challenge.verified? && challenge.verified_at.present? && challenge.expires_at > at &&
        challenge.verified_at >= at - maximum_age
    end

    def dns_recheck_due?(challenge:, at: Time.current)
      return false unless challenge.method == "dns_txt" && challenge.verified? &&
        challenge.verified_at.present? && challenge.expires_at > at
      return false unless challenge.verified_at <= at - DNS_RECHECK_INTERVAL

      challenge.attempted_at.nil? || challenge.attempted_at <= challenge.verified_at ||
        challenge.attempted_at <= at - DNS_RECHECK_RETRY_INTERVAL
    end
  end
end
