# frozen_string_literal: true

module Verification
  class DnsRecheckSweepJob < ApplicationJob
    class_attribute :scheduler_builder, default: -> { VerificationFactory.dns_recheck_scheduler }

    runs_on :maintenance
    system_authorization :dns_verification_recheck_sweep,
      reason: "schedules bounded refresh checks for stale DNS ownership proofs"

    def perform
      self.class.scheduler_builder.call.call
    end
  end
end
