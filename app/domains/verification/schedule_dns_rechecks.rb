# frozen_string_literal: true

module Verification
  class ScheduleDnsRechecks
    BATCH_SIZE = 200

    def initialize(clock: -> { Time.current }, enqueue: ->(organization_id, challenge_id) {
      DnsRecheckJob.perform_later(organization_id: organization_id, challenge_id: challenge_id)
    })
      @clock = clock
      @enqueue = enqueue
    end

    def call
      at = @clock.call
      candidates(at).pluck(:organization_id, :id).each do |organization_id, challenge_id|
        @enqueue.call(organization_id, challenge_id)
      end.length
    end

    private

    def candidates(at)
      Challenge.where(method: "dns_txt", state: "verified")
        .where("verified_at <= ? AND expires_at > ?", at - FreshnessPolicy::DNS_RECHECK_INTERVAL, at)
        .where(
          "attempted_at IS NULL OR attempted_at <= verified_at OR attempted_at <= ?",
          at - FreshnessPolicy::DNS_RECHECK_RETRY_INTERVAL
        )
        .order(:verified_at, :id)
        .limit(BATCH_SIZE)
    end
  end
end
