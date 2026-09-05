# frozen_string_literal: true

module Crawling
  class TargetUnavailable < Shared::Public::TransientInfrastructureError
    def initialize(reason_code: "scan_target_unavailable")
      super(reason_code: reason_code)
    end

    def definition
      super.with(
        public_code: "target_unavailable",
        public_message: "The scan target could not be reached by the bounded preflight check."
      )
    end
  end
end
