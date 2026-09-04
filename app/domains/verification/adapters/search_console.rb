# frozen_string_literal: true

module Verification
  module Adapters
    class SearchConsole
      attr_reader :method

      def initialize(client:)
        raise ArgumentError, "client must implement verified_property?" unless client.respond_to?(:verified_property?)

        @client = client
        @method = "search_console"
      end

      def verify(challenge:, expected_value:)
        matched = @client.verified_property?(origin: challenge.bound_origin) == true
        AdapterResult.new(
          verified: matched,
          failure_category: ("provider_unauthorized" unless matched),
          evidence: { provider_property_match: matched }
        )
      rescue StandardError
        AdapterResult.new(verified: false, failure_category: "provider_unavailable")
      end
    end
  end
end
