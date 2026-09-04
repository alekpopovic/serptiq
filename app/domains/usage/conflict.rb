# frozen_string_literal: true

module Usage
  class Conflict < Shared::Public::ConflictError
    def initialize(reason_code: "usage_conflict")
      super
    end
  end
end
