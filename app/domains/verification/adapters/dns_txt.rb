# frozen_string_literal: true

module Verification
  module Adapters
    class DnsTxt
      attr_reader :method

      def initialize(resolver:)
        raise ArgumentError, "resolver must implement txt_records" unless resolver.respond_to?(:txt_records)

        @resolver = resolver
        @method = "dns_txt"
      end

      def verify(challenge:, expected_value:)
        records = Array(@resolver.txt_records(name: challenge.expected_location)).first(100)
        matched = records.any? { |record| ChallengeToken.valid_for?(challenge, record.to_s) }
        AdapterResult.new(
          verified: matched,
          failure_category: ("proof_mismatch" unless matched),
          evidence: { matched: matched, record_count: records.length }
        )
      rescue StandardError
        AdapterResult.new(verified: false, failure_category: "provider_unavailable")
      end
    end
  end
end
