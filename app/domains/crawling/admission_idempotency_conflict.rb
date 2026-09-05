# frozen_string_literal: true

module Crawling
  class AdmissionIdempotencyConflict < Shared::Public::ConflictError
    def initialize(reason_code: "scan_admission_idempotency_conflict")
      super(reason_code: reason_code)
    end

    def definition
      super.with(
        public_code: "idempotency_conflict",
        public_message: "That idempotency key was already used for a different scan request."
      )
    end
  end
end
