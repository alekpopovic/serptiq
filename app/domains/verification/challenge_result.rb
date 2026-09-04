# frozen_string_literal: true

module Verification
  ChallengeResult = Data.define(:challenge, :changed) do
    def initialize(challenge:, changed:)
      super(challenge: challenge, changed: !!changed)
      freeze
    end

    def changed?
      changed
    end
  end
end
