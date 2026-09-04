# frozen_string_literal: true

module Verification
  IssuedChallenge = Data.define(:challenge, :instructions) do
    def initialize(challenge:, instructions:)
      super
      freeze
    end
  end
end
