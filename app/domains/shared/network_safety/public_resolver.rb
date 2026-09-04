# frozen_string_literal: true

require "resolv"
require "timeout"

module Shared
  module NetworkSafety
    class PublicResolver
      MAX_ADDRESSES = 16

      def initialize(timeout: 3.seconds, max_addresses: MAX_ADDRESSES)
        @timeout = Float(timeout)
        @max_addresses = Integer(max_addresses)
      end

      def resolve(host:)
        dns = Resolv::DNS.new
        dns.timeouts = @timeout
        addresses = Timeout.timeout(@timeout) do
          dns.getaddresses(Resolv::DNS::Name.create("#{host}."))
        end.map(&:to_s).uniq
        raise Error.new(reason_code: "dns_failure") if addresses.empty?
        raise Error.new(reason_code: "unsafe_destination") if addresses.length > @max_addresses

        addresses.freeze
      rescue Resolv::ResolvTimeout, Timeout::Error
        raise Error.new(reason_code: "timeout"), cause: nil
      rescue Resolv::ResolvError, IOError, SocketError, SystemCallError
        raise Error.new(reason_code: "dns_failure"), cause: nil
      ensure
        dns&.close
      end
    end
  end
end
