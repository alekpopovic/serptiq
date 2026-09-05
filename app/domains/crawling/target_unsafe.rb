# frozen_string_literal: true

module Crawling
  class TargetUnsafe < Shared::Public::UnsafeDestinationError
    def initialize(reason_code: "scan_target_unsafe")
      super(reason_code: reason_code)
    end

    def definition
      super.with(
        public_code: "unsafe_target",
        public_message: "The scan target did not pass the public-network safety policy."
      )
    end
  end
end
