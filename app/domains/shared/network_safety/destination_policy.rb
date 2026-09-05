# frozen_string_literal: true

require "ipaddr"

module Shared
  module NetworkSafety
    class DestinationPolicy
      NullRecorder = ->(**) { }

      def initialize(resolver: PublicResolver.new, address_policy: AddressPolicy.new, recorder: NullRecorder)
        raise ArgumentError, "destination recorder must implement call" unless recorder.respond_to?(:call)

        @resolver = resolver
        @address_policy = address_policy
        @recorder = recorder
      end

      def authorize!(url:)
        authorize_target!(target: HttpTarget.new(url: url))
      rescue ArgumentError
        error = Error.new(reason_code: "unsafe_destination", evidence: { denial_stage: "url_parse" })
        record_denial(error)
        raise error, cause: nil
      end

      def authorize_target!(target:)
        raise ArgumentError, "destination target is invalid" unless target.is_a?(HttpTarget)

        @address_policy.approve_port!(target.port)
        addresses = @resolver.resolve(host: target.host)
        approved = @address_policy.approve!(host: target.host, port: target.port, addresses: addresses)
        destination = build_destination(target, approved)
        record(outcome: "succeeded", reason_code: nil, evidence: destination.provenance.as_json)
        destination
      rescue Error => error
        record_denial(error)
        raise
      rescue ArgumentError, KeyError, TypeError
        error = Error.new(reason_code: "unsafe_destination", evidence: { denial_stage: "url_parse" })
        record_denial(error)
        raise error, cause: nil
      end

      private

      def build_destination(target, addresses)
        parsed = addresses.map { |address| IPAddr.new(address) }
        ipv4_count = parsed.count(&:ipv4?)
        provenance = ResolutionProvenance.new(
          address_count: parsed.length,
          ipv4_address_count: ipv4_count,
          ipv6_address_count: parsed.length - ipv4_count,
          destination_port: target.port,
          address_policy_version: AddressPolicy::POLICY_VERSION
        )
        ApprovedDestination.new(
          target: target,
          ip_addresses: addresses,
          port: target.port,
          provenance: provenance
        )
      end

      def record_denial(error)
        record(outcome: "denied", reason_code: error.reason_code, evidence: error.evidence)
      end

      def record(**attributes)
        @recorder.call(**attributes)
      rescue StandardError => error
        Rails.error.report(
          error,
          handled: true,
          severity: :warning,
          context: { "failed_event" => "crawler.destination_rejected" }
        )
      end
    end
  end
end
