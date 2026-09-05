# frozen_string_literal: true

require "resolv"
require "timeout"

module Shared
  module NetworkSafety
    class PublicResolver
      MAX_ADDRESSES = 16

      def initialize(timeout: 3.seconds, max_addresses: MAX_ADDRESSES, dns_factory: -> { Resolv::DNS.new })
        @timeout = Float(timeout)
        @max_addresses = Integer(max_addresses)
        @dns_factory = dns_factory
        valid = @timeout.between?(0.1, 10) && @max_addresses.between?(1, MAX_ADDRESSES) &&
          @dns_factory.respond_to?(:call)
        raise ArgumentError, "resolver limits are invalid" unless valid
      end

      def resolve(host:)
        dns = @dns_factory.call
        dns.timeouts = @timeout
        name = Resolv::DNS::Name.create("#{host}.")
        addresses = Timeout.timeout(@timeout) do
          [ Resolv::DNS::Resource::IN::A, Resolv::DNS::Resource::IN::AAAA ].flat_map do |resource_type|
            dns.getresources(name, resource_type).map(&:address)
          end
        end.map(&:to_s).uniq
        if addresses.empty?
          raise Error.new(
            reason_code: "dns_failure",
            evidence: { denial_stage: "dns_resolution", address_count: 0 }
          )
        end
        if addresses.length > @max_addresses
          raise Error.new(
            reason_code: "unsafe_destination",
            evidence: { denial_stage: "dns_resolution", address_count: addresses.length }
          )
        end

        addresses.freeze
      rescue Resolv::ResolvTimeout, Timeout::Error
        raise Error.new(
          reason_code: "timeout",
          evidence: { denial_stage: "dns_resolution", address_count: 0 }
        ), cause: nil
      rescue Resolv::ResolvError, IOError, SocketError, SystemCallError, ArgumentError, TypeError
        raise Error.new(
          reason_code: "dns_failure",
          evidence: { denial_stage: "dns_resolution", address_count: 0 }
        ), cause: nil
      ensure
        dns&.close
      end
    end
  end
end
