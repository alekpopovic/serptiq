# frozen_string_literal: true

module Verification
  module Adapters
    class HtmlFile
      attr_reader :method

      def initialize(fetcher:)
        raise ArgumentError, "fetcher must implement fetch_exact" unless fetcher.respond_to?(:fetch_exact)

        @fetcher = fetcher
        @method = "html_file"
      end

      def verify(challenge:, expected_value:)
        response = @fetcher.fetch_exact(origin: challenge.bound_origin, url: challenge.expected_location)
        body = response.fetch(:body).to_s
        status = Integer(response.fetch(:status))
        final_match = response.fetch(:final_origin).to_s == challenge.bound_origin
        matched = status == 200 && final_match &&
          ActiveSupport::SecurityUtils.secure_compare(
            ChallengeToken.digest(body.strip), ChallengeToken.digest(expected_value)
          )
        category = if !final_match then "unsafe_destination"
        elsif status == 404 then "proof_missing"
        else "proof_mismatch"
        end
        AdapterResult.new(
          verified: matched,
          failure_category: (category unless matched),
          evidence: {
            matched: matched, status_code: status, byte_count: body.bytesize,
            final_origin_match: final_match
          }
        )
      rescue KeyError, ArgumentError, TypeError
        AdapterResult.new(verified: false, failure_category: "malformed_response")
      rescue StandardError
        AdapterResult.new(verified: false, failure_category: "provider_unavailable")
      end
    end
  end
end
