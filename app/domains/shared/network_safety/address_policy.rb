# frozen_string_literal: true

require "ipaddr"

module Shared
  module NetworkSafety
    class AddressPolicy
      BLOCKED_NETWORKS = %w[
        0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
        172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16
        198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
        ::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 64:ff9b:1::/48 100::/64
        2001::/23 2001:db8::/32 2002::/16 3fff::/20 5f00::/16 fc00::/7 fe80::/10 fec0::/10 ff00::/8
      ].map { |cidr| IPAddr.new(cidr) }.freeze
      ALLOWED_PORTS = [ 80, 443 ].freeze

      def initialize(allowed_ports: ALLOWED_PORTS)
        @allowed_ports = Array(allowed_ports).map { |port| Integer(port) }.uniq.freeze
      end

      def approve!(host:, port:, addresses:)
        raise Error.new(reason_code: "unsafe_destination") unless @allowed_ports.include?(port)

        values = Array(addresses)
        raise Error.new(reason_code: "dns_failure") if values.empty?

        parsed = values.map { |value| parse_address(value) }
        raise Error.new(reason_code: "unsafe_destination") if parsed.any? { |address| blocked?(address) }

        parsed.map(&:to_s).freeze
      rescue IPAddr::InvalidAddressError, ArgumentError
        raise Error.new(reason_code: "unsafe_destination"), cause: nil
      end

      private

      def parse_address(value)
        address = IPAddr.new(value.to_s)
        address = address.native if address.ipv4_mapped?
        address
      end

      def blocked?(address)
        BLOCKED_NETWORKS.any? { |network| network.include?(address) }
      end
    end
  end
end
