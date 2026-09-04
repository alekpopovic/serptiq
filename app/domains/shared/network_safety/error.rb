# frozen_string_literal: true

module Shared
  module NetworkSafety
    class Error < StandardError
      REASON_CODES = %w[
        unsafe_destination dns_failure timeout transport_failure redirect_rejected redirect_limit
        response_too_large content_type_rejected malformed_response
      ].freeze

      attr_reader :reason_code, :evidence

      def initialize(reason_code:, evidence: {}, message: "safe HTTP request rejected")
        code = reason_code.to_s
        raise ArgumentError, "invalid network safety reason" unless REASON_CODES.include?(code)

        @reason_code = code.freeze
        @evidence = sanitize_evidence(evidence)
        super(message)
      end

      private

      def sanitize_evidence(value)
        source = value.is_a?(Hash) ? value : {}
        source.slice(:status_code, :byte_count, :redirect_count, :content_type_allowed,
          :destination_approved, :request_match).transform_values do |item|
          case item
          when true, false then item
          when Integer then item.clamp(0, 1_000_000)
          end
        end.compact.freeze
      end
    end
  end
end
