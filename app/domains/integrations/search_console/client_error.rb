# frozen_string_literal: true

module Integrations
  module SearchConsole
    class ClientError < StandardError
      REASONS = %w[revoked_scope inaccessible_property outage malformed_response].freeze

      attr_reader :reason_code

      def initialize(reason_code)
        reason = reason_code.to_s
        raise ArgumentError, "Search Console client error is invalid" unless REASONS.include?(reason)

        @reason_code = reason.freeze
        super("Search Console request failed")
      end
    end
  end
end
