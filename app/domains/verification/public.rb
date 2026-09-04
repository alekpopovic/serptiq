# frozen_string_literal: true

module Verification
  module Public
    module_function

    def issue_challenge(clock: -> { Time.current }, search_console_client: nil, **attributes)
      client = search_console_client || VerificationFactory.search_console_client
      IssueChallenge.new(
        clock: clock,
        selection_resolver: SearchConsoleSelectionResolver.new(client: client, clock: clock)
      ).call(**attributes)
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

    def search_console_catalog(search_console_client: nil, **attributes)
      client = search_console_client || VerificationFactory.search_console_client
      SearchConsoleCatalog.new(client: client).call(**attributes)
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
