# frozen_string_literal: true

module Shared
  module NetworkSafety
    class Error < StandardError
      REASON_CODES = %w[
        unsafe_destination dns_failure timeout transport_failure redirect_rejected redirect_limit
        connect_timeout tls_timeout header_timeout body_timeout total_timeout tls_certificate
        tls_protocol header_too_large response_too_large decompression_limit
        unsupported_content_encoding content_type_rejected malformed_response canceled
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
        evidence = {}
        %i[content_encoding_supported content_type_allowed destination_approved request_match].each do |name|
          evidence[name] = source[name] if source[name].in?([ true, false ])
        end
        {
          status_code: 599,
          byte_count: 50.megabytes,
          header_byte_count: 262_144,
          compressed_byte_count: 104_857_600,
          decoded_byte_count: 524_288_000,
          duration_ms: 600_000,
          attempt_count: 10,
          retry_count: 10,
          redirect_count: 5,
          address_count: PublicResolver::MAX_ADDRESSES,
          ipv4_address_count: PublicResolver::MAX_ADDRESSES,
          ipv6_address_count: PublicResolver::MAX_ADDRESSES,
          destination_port: 65_535,
          resolution_count: 6
        }.each do |name, maximum|
          evidence[name] = source[name].clamp(0, maximum) if source[name].is_a?(Integer)
        end
        if %w[
          url_parse port_policy dns_resolution address_parse address_policy redirect_policy
          connect tls headers body decompression transport
        ].include?(
          source[:denial_stage].to_s
        )
          evidence[:denial_stage] = source[:denial_stage].to_s.freeze
        end
        if source[:address_policy_version].to_s == AddressPolicy::POLICY_VERSION
          evidence[:address_policy_version] = AddressPolicy::POLICY_VERSION
        end
        evidence.freeze
      end
    end
  end
end
