# frozen_string_literal: true

module Authorization
  class ApiErrorContract
    CODE = "authorization_denied"

    def self.call(error, request_id:)
      raise ArgumentError, "authorization error is required" unless error.is_a?(AccessDenied)

      {
        error: {
          code: CODE,
          reason_code: error.decision.reason_code,
          request_id: request_id.to_s
        }.freeze
      }.freeze
    end
  end
end
