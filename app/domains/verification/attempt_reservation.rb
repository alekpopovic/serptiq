# frozen_string_literal: true

module Verification
  AttemptReservation = Data.define(:challenge_id, :sequence, :expected_value, :attempted_at) do
    def initialize(challenge_id:, sequence:, expected_value:, attempted_at:)
      super(
        challenge_id: challenge_id.to_s.freeze,
        sequence: Integer(sequence),
        expected_value: expected_value.to_s.freeze,
        attempted_at: attempted_at
      )
      freeze
    end
  end
end
