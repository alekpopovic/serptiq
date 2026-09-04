# frozen_string_literal: true

module Verification
  module Adapters
    class DnsTxt
      attr_reader :method

      FAILURE_BY_STATUS = {
        "nxdomain" => "dns_nxdomain",
        "no_record" => "dns_no_record",
        "timeout" => "dns_timeout",
        "transient_failure" => "dns_transient_failure",
        "response_limit" => "dns_response_limit",
        "cname_limit" => "dns_cname_limit",
        "delegation_limit" => "dns_delegation_limit",
        "malformed_response" => "malformed_response"
      }.freeze
      PROPAGATION_WINDOW = 15.minutes

      def initialize(resolver:, clock: -> { Time.current })
        raise ArgumentError, "resolver must implement resolve" unless resolver.respond_to?(:resolve)

        @resolver = resolver
        @clock = clock
        @method = "dns_txt"
      end

      def verify(challenge:, expected_value:)
        return failure("malformed_response", question_match: false) unless
          ChallengeToken.valid_for?(challenge, expected_value)

        resolution = @resolver.resolve(name: challenge.expected_location)
        return failure(FAILURE_BY_STATUS.fetch(resolution.status), **resolution.evidence) unless
          resolution.resolved?

        matches = resolution.records.count { |record| exact_match?(expected_value, record) }
        matched = matches == 1
        category = if matched
          nil
        elsif matches > 1 || resolution.record_count > 1
          "dns_multiple_records"
        elsif propagating?(challenge)
          "dns_propagating"
        else
          "proof_mismatch"
        end
        AdapterResult.new(
          verified: matched,
          failure_category: category,
          evidence: resolution.evidence.merge(matched: matched)
        )
      rescue StandardError
        failure("dns_transient_failure")
      end

      private

      def exact_match?(expected, observed)
        ActiveSupport::SecurityUtils.secure_compare(
          ChallengeToken.digest(expected), ChallengeToken.digest(observed)
        )
      end

      def propagating?(challenge)
        challenge.respond_to?(:created_at) && challenge.created_at &&
          challenge.created_at + PROPAGATION_WINDOW > @clock.call
      end

      def failure(category, **evidence)
        AdapterResult.new(verified: false, failure_category: category, evidence: evidence)
      end
    end
  end
end
