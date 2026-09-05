# frozen_string_literal: true

module Crawling
  class VerificationRequired < Shared::Public::ConflictError
    def initialize(reason_code: "scan_verification_required")
      super(reason_code: reason_code)
    end

    def definition
      super.with(
        public_code: "verification_required",
        public_message: "A current ownership verification is required before this scan can run."
      )
    end
  end
end
