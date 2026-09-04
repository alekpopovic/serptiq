# frozen_string_literal: true

require "nokogiri"

module Verification
  module Adapters
    class MetaTag
      attr_reader :method

      FAILURE_BY_NETWORK_REASON = HtmlFile::FAILURE_BY_NETWORK_REASON

      def initialize(fetcher:)
        raise ArgumentError, "fetcher must implement fetch_exact" unless fetcher.respond_to?(:fetch_exact)

        @fetcher = fetcher
        @method = "meta_tag"
      end

      def verify(challenge:, expected_value:)
        return failure("malformed_response", request_match: false) unless
          ChallengeToken.valid_for?(challenge, expected_value)

        response = @fetcher.fetch_exact(
          origin: challenge.bound_origin,
          url: challenge.expected_location,
          allowed_content_types: [ "text/html" ],
          approved_redirect_origins: CanonicalRedirectOrigins.for(challenge.bound_origin)
        )
        body = response.fetch(:body).to_s.b
        status = Integer(response.fetch(:status))
        destination_approved = response.fetch(:destination_approved)
        request_match = response.fetch(:request_match) && response.fetch(:final_url).to_s.end_with?("/")
        tags = if status == 200 && destination_approved && request_match
          Nokogiri::HTML5.parse(body).css('meta[name="searchops-verification"]')
        else
          []
        end
        content = tags.sole["content"] if tags.one?
        matched = tags.one? && content.present? && ChallengeToken.valid_for?(challenge, content)
        category = if !destination_approved then "unsafe_destination"
        elsif !request_match then "http_redirect_rejected"
        elsif status == 404 then "proof_missing"
        elsif tags.many? then "duplicate_meta"
        else "proof_mismatch"
        end
        AdapterResult.new(
          verified: matched,
          failure_category: (category unless matched),
          evidence: {
            matched: matched,
            status_code: status,
            byte_count: body.bytesize,
            final_origin_match: response.fetch(:final_origin).to_s == challenge.bound_origin,
            destination_approved: destination_approved,
            request_match: request_match,
            redirect_count: response.fetch(:redirect_count),
            content_type_allowed: response.fetch(:content_type_allowed),
            meta_count: tags.length
          }
        )
      rescue Shared::Public::NetworkSafetyError => error
        failure(FAILURE_BY_NETWORK_REASON.fetch(error.reason_code), **error.evidence)
      rescue KeyError, ArgumentError, TypeError, Nokogiri::SyntaxError
        failure("malformed_response")
      rescue StandardError
        failure("http_transport_failure")
      end

      private

      def failure(category, **evidence)
        AdapterResult.new(verified: false, failure_category: category, evidence: evidence)
      end
    end
  end
end
