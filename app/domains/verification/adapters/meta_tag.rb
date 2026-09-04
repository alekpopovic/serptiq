# frozen_string_literal: true

require "nokogiri"

module Verification
  module Adapters
    class MetaTag
      attr_reader :method

      def initialize(fetcher:)
        raise ArgumentError, "fetcher must implement fetch_exact" unless fetcher.respond_to?(:fetch_exact)

        @fetcher = fetcher
        @method = "meta_tag"
      end

      def verify(challenge:, expected_value:)
        response = @fetcher.fetch_exact(origin: challenge.bound_origin, url: challenge.expected_location)
        body = response.fetch(:body).to_s
        status = Integer(response.fetch(:status))
        final_match = response.fetch(:final_origin).to_s == challenge.bound_origin
        content = if status == 200 && final_match
          Nokogiri::HTML5.parse(body).at_css('meta[name="searchops-verification"]')&.[]("content")
        end
        matched = content.present? && ChallengeToken.valid_for?(challenge, content)
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
      rescue KeyError, ArgumentError, TypeError, Nokogiri::SyntaxError
        AdapterResult.new(verified: false, failure_category: "malformed_response")
      rescue StandardError
        AdapterResult.new(verified: false, failure_category: "provider_unavailable")
      end
    end
  end
end
