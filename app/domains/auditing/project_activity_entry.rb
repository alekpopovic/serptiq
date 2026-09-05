# frozen_string_literal: true

module Auditing
  ProjectActivityEntry = Data.define(:action, :result, :target_type, :occurred_at) do
    def initialize(action:, result:, target_type:, occurred_at:)
      super(
        action: action.to_s.freeze,
        result: result.to_s.freeze,
        target_type: target_type.to_s.freeze,
        occurred_at: occurred_at
      )
      freeze
    end
  end
end
