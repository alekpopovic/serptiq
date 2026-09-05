# frozen_string_literal: true

module Crawling
  class CapacityExceeded < Shared::Public::ConflictError
    attr_reader :scope

    def initialize(scope:, reason_code: "scan_capacity_exceeded")
      @scope = scope.to_s.freeze
      super(reason_code: reason_code)
    end

    def definition
      super.with(
        public_code: "scan_capacity_exceeded",
        public_message: "The concurrent scan limit is currently in use. Try again after active work finishes."
      )
    end
  end
end
