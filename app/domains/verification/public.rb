# frozen_string_literal: true

module Verification
  module Public
    module_function

    def issue_challenge(clock: -> { Time.current }, **attributes)
      IssueChallenge.new(clock: clock).call(**attributes)
    end

    def attempt_challenge(clock: -> { Time.current }, registry: nil, **attributes)
      registry ||= VerificationFactory.adapter_registry
      AttemptChallenge.new(clock: clock, registry: registry).call(**attributes)
    end

    def revoke_challenge(clock: -> { Time.current }, **attributes)
      RevokeChallenge.new(clock: clock).call(**attributes)
    end

    def challenge_details(**attributes)
      ChallengeDirectory.new.latest(**attributes)
    end

    def fresh_verification(**attributes)
      FreshVerification.new.call(**attributes)
    end

    def schedule_dns_rechecks(clock: -> { Time.current }, **attributes)
      ScheduleDnsRechecks.new(clock: clock, **attributes).call
    end

    def recheck_dns_challenge(adapter:, clock: -> { Time.current }, **attributes)
      RecheckDnsChallenge.new(adapter: adapter, clock: clock).call(**attributes)
    end
  end
end
