# frozen_string_literal: true

module Verification
  class DnsRecheckJob < ApplicationJob
    class_attribute :rechecker_builder, default: -> { VerificationFactory.dns_rechecker }

    runs_on :maintenance
    system_authorization :dns_verification_recheck,
      reason: "revalidates one explicit tenant-bound DNS ownership proof"

    def perform(organization_id:, challenge_id:)
      self.class.rechecker_builder.call.call(
        organization_id: organization_id,
        challenge_id: challenge_id
      )
    end
  end
end
