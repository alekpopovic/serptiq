# frozen_string_literal: true

module Shared
  module NetworkSafety
    class SafeHttpClient
      REDIRECT_STATUSES = [ 301, 302, 303, 307, 308 ].freeze

      def initialize(resolver: PublicResolver.new, address_policy: AddressPolicy.new,
        transport: NetHttpTransport.new, open_timeout: 2.seconds, read_timeout: 5.seconds,
        max_response_bytes: 256.kilobytes, max_redirects: 2)
        @resolver = resolver
        @address_policy = address_policy
        @transport = transport
        @open_timeout = Float(open_timeout)
        @read_timeout = Float(read_timeout)
        @max_response_bytes = Integer(max_response_bytes)
        @max_redirects = Integer(max_redirects)
        validate_limits!
      end

      def fetch_exact(origin:, url:, allowed_content_types:, approved_redirect_origins: [])
        policy = ExactRedirectPolicy.new(
          origin: origin,
          url: url,
          approved_redirect_origins: approved_redirect_origins
        )
        target = policy.initial_target
        redirects = 0

        loop do
          addresses = @resolver.resolve(host: target.host)
          approved = @address_policy.approve!(host: target.host, port: target.port, addresses: addresses)
          response = @transport.get(
            target: target,
            ip_address: approved.first,
            open_timeout: @open_timeout,
            read_timeout: @read_timeout,
            max_response_bytes: @max_response_bytes
          )
          reject_oversized!(response, redirects)
          if REDIRECT_STATUSES.include?(response.status)
            redirects += 1
            raise Error.new(reason_code: "redirect_limit", evidence: { redirect_count: redirects }) if
              redirects > @max_redirects

            target = policy.redirect(current: target, location: response.headers["location"])
            next
          end

          content_type_allowed = content_type_allowed?(response, allowed_content_types)
          if response.status.between?(200, 299) && !content_type_allowed
            raise Error.new(
              reason_code: "content_type_rejected",
              evidence: {
                status_code: response.status,
                byte_count: response.body.bytesize,
                redirect_count: redirects,
                content_type_allowed: false,
                destination_approved: true,
                request_match: true
              }
            )
          end
          return {
            status: response.status,
            body: response.body,
            final_origin: target.origin,
            final_url: target.url,
            redirect_count: redirects,
            content_type_allowed: content_type_allowed,
            destination_approved: policy.approved_origin?(target.origin),
            request_match: true
          }.freeze
        end
      rescue Error => error
        rejected_destination = %w[unsafe_destination dns_failure redirect_rejected].include?(error.reason_code)
        evidence = { destination_approved: !rejected_destination }.merge(error.evidence)
        raise Error.new(reason_code: error.reason_code, evidence: evidence), cause: nil
      rescue ArgumentError, KeyError, TypeError
        raise Error.new(reason_code: "malformed_response"), cause: nil
      end

      private

      def reject_oversized!(response, redirects)
        return if response.body.bytesize <= @max_response_bytes

        raise Error.new(
          reason_code: "response_too_large",
          evidence: { byte_count: response.body.bytesize, redirect_count: redirects }
        )
      end

      def content_type_allowed?(response, allowed)
        observed = response.headers.fetch("content-type", "").split(";", 2).first.to_s.strip.downcase
        Array(allowed).map { |value| value.to_s.downcase }.include?(observed)
      end

      def validate_limits!
        valid = @open_timeout.between?(0.1, 10) && @read_timeout.between?(0.1, 30) &&
          @max_response_bytes.between?(128, 1.megabyte) && @max_redirects.between?(0, 5)
        raise ArgumentError, "safe HTTP client limits are invalid" unless valid
      end
    end
  end
end
