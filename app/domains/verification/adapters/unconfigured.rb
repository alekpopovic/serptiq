# frozen_string_literal: true

module Verification
  module Adapters
    class Unconfigured
      attr_reader :method

      def initialize(method:)
        @method = method.to_s.freeze
      end

      def verify(challenge:, expected_value:)
        challenge
        expected_value
        AdapterResult.new(verified: false, failure_category: "provider_unavailable")
      end
    end
  end
end
