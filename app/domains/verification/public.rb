# frozen_string_literal: true

module Verification
  module Public
    module_function

    def issue_challenge(clock: -> { Time.current }, **attributes)
      IssueChallenge.new(clock: clock).call(**attributes)
    end

    def attempt_challenge(clock: -> { Time.current }, registry: AdapterRegistry.unconfigured, **attributes)
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
  end
end
