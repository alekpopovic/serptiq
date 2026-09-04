# frozen_string_literal: true

module Projects
  class ProjectTransitionInvalid < Shared::Public::ConflictError
    def initialize(reason_code: "project_transition_invalid")
      super(reason_code: reason_code)
    end
  end
end
