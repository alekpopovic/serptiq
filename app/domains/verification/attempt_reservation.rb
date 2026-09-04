# frozen_string_literal: true

module Verification
  AttemptReservation = Data.define(:challenge_id, :sequence, :expected_value) do
    def initialize(challenge_id:, sequence:, expected_value:)
      super(
        challenge_id: challenge_id.to_s.freeze,
        sequence: Integer(sequence),
        expected_value: expected_value.to_s.freeze
      )
      freeze
    end
  end
end
