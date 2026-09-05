# frozen_string_literal: true

module Shared
  module NetworkSafety
    class SafeHttpClient
      REDIRECT_STATUSES = [ 301, 302, 303, 307, 308 ].freeze

      def initialize(destination_policy: nil, resolver: PublicResolver.new, address_policy: AddressPolicy.new,
        transport: NetHttpTransport.new, decision_recorder: DestinationPolicy::NullRecorder,
        open_timeout: 2.seconds, read_timeout: 5.seconds, max_response_bytes: 256.kilobytes,
        max_redirects: 2)
        @destination_policy = destination_policy || DestinationPolicy.new(
          resolver: resolver,
          address_policy: address_policy,
          recorder: decision_recorder
        )
        @decision_recorder = decision_recorder
        @transport = transport
        @open_timeout = Float(open_timeout)
        @read_timeout = Float(read_timeout)
        @max_response_bytes = Integer(max_response_bytes)
        @max_redirects = Integer(max_redirects)
        validate_limits!
      end

      def fetch_exact(origin:, url:, allowed_content_types:, approved_redirect_origins: [], user_agent: nil,
        request_observer: nil)
        policy = ExactRedirectPolicy.new(
          origin: origin,
          url: url,
          approved_redirect_origins: approved_redirect_origins
        )
        fetch_with_policy(policy, allowed_content_types, user_agent, request_observer)
      end

      def fetch_public_redirects(origin:, url:, allowed_content_types:, approved_redirect_origins: nil,
        user_agent: nil, request_observer: nil)
        policy = PublicRedirectPolicy.new(
          origin: origin,
          url: url,
          approved_redirect_origins: approved_redirect_origins
        )
        fetch_with_policy(policy, allowed_content_types, user_agent, request_observer)
      end

      private

      def fetch_with_policy(policy, allowed_content_types, user_agent, request_observer)
        validate_request_observer!(request_observer)
        target = policy.initial_target
        redirects = 0
        resolution_attempts = 0
        resolution_provenance = []
        request_sequence = nil
        observed_operation = nil

        loop do
          request_sequence = resolution_attempts + 1
          observed_operation = request_observer&.before_request(sequence: request_sequence)
          resolution_attempts += 1
          destination = @destination_policy.authorize_target!(target: target)
          resolution_provenance << destination.provenance.as_json
          response = @transport.get(
            destination: destination,
            open_timeout: @open_timeout,
            read_timeout: @read_timeout,
            max_response_bytes: @max_response_bytes,
            user_agent: user_agent
          )
          completed_operation = observed_operation
          observed_operation = nil
          request_observer&.after_response(
            sequence: request_sequence,
            operation: completed_operation,
            status: response.status
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
            content_type: media_type(response),
            content_type_allowed: content_type_allowed,
            destination_approved: policy.approved_origin?(target.origin),
            request_match: true,
            resolution_provenance: resolution_provenance.map(&:freeze).freeze
          }.freeze
        end
      rescue Error => error
        request_observer&.after_failure(
          sequence: request_sequence,
          operation: observed_operation,
          reason_code: error.reason_code
        ) if observed_operation
        rejected_destination = %w[unsafe_destination dns_failure redirect_rejected].include?(error.reason_code)
        evidence = {
          destination_approved: !rejected_destination,
          redirect_count: redirects,
          resolution_count: resolution_attempts
        }.merge(error.evidence)
        record_redirect_denial(error, evidence) if error.reason_code.in?(%w[redirect_rejected redirect_limit])
        raise Error.new(reason_code: error.reason_code, evidence: evidence), cause: nil
      rescue ArgumentError, KeyError, TypeError
        request_observer&.after_failure(
          sequence: request_sequence,
          operation: observed_operation,
          reason_code: "malformed_response"
        ) if observed_operation
        raise Error.new(reason_code: "malformed_response"), cause: nil
      end

      def validate_request_observer!(observer)
        return unless observer
        return if observer.respond_to?(:before_request) && observer.respond_to?(:after_response) &&
          observer.respond_to?(:after_failure)

        raise ArgumentError, "HTTP request observer is invalid"
      end

      def reject_oversized!(response, redirects)
        return if response.body.bytesize <= @max_response_bytes

        raise Error.new(
          reason_code: "response_too_large",
          evidence: { byte_count: response.body.bytesize, redirect_count: redirects }
        )
      end

      def content_type_allowed?(response, allowed)
        observed = media_type(response)
        Array(allowed).map { |value| value.to_s.downcase }.include?(observed)
      end

      def media_type(response)
        response.headers.fetch("content-type", "").split(";", 2).first.to_s.strip.downcase
      end

      def validate_limits!
        valid = @open_timeout.between?(0.1, 10) && @read_timeout.between?(0.1, 30) &&
          @max_response_bytes.between?(128, 50.megabytes) && @max_redirects.between?(0, 5)
        raise ArgumentError, "safe HTTP client limits are invalid" unless valid
      end

      def record_redirect_denial(error, evidence)
        @decision_recorder.call(
          outcome: "denied",
          reason_code: error.reason_code,
          evidence: evidence.merge(denial_stage: "redirect_policy")
        )
      rescue StandardError => recorder_error
        Rails.error.report(
          recorder_error,
          handled: true,
          severity: :warning,
          context: { "failed_event" => "crawler.destination_rejected" }
        )
      end
    end
  end
end
