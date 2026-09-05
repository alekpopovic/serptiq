# frozen_string_literal: true

require "ipaddr"

module Shared
  module NetworkSafety
    class AddressPolicy
      POLICY_VERSION = "iana-special-purpose-2025-10-09"
      IPV4_BLOCKED_NETWORKS = %w[
        0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
        172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16
        198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
      ].map { |cidr| IPAddr.new(cidr) }.freeze
      IPV4_ALLOWED_SPECIAL_NETWORKS = %w[
        192.0.0.9/32 192.0.0.10/32
      ].map { |cidr| IPAddr.new(cidr) }.freeze
      IPV6_BLOCKED_NETWORKS = %w[
        ::/96 64:ff9b::/96 64:ff9b:1::/48 100::/64 100:0:0:1::/64
        2001::/23 2001:db8::/32 2002::/16 3fff::/20 5f00::/16
      ].map { |cidr| IPAddr.new(cidr) }.freeze
      IPV6_ALLOWED_SPECIAL_NETWORKS = %w[
        2001:1::1/128 2001:1::2/128 2001:1::3/128
        2001:3::/32 2001:4:112::/48 2001:20::/28 2001:30::/28
      ].map { |cidr| IPAddr.new(cidr) }.freeze
      IPV6_GLOBAL_UNICAST = IPAddr.new("2000::/3")
      ALLOWED_PORTS = [ 80, 443 ].freeze

      def initialize(allowed_ports: ALLOWED_PORTS)
        @allowed_ports = Array(allowed_ports).map { |port| Integer(port) }.uniq.freeze
      end

      def approve!(host:, port:, addresses:)
        normalized_port = approve_port!(port)

        values = Array(addresses)
        if values.empty?
          raise Error.new(
            reason_code: "dns_failure",
            evidence: empty_provenance(normalized_port).merge(denial_stage: "dns_resolution")
          )
        end

        parsed = values.map { |value| parse_address(value) }.uniq
        if parsed.any? { |address| blocked?(address) }
          raise Error.new(
            reason_code: "unsafe_destination",
            evidence: provenance(parsed, normalized_port).merge(denial_stage: "address_policy")
          )
        end

        parsed.map(&:to_s).freeze
      rescue IPAddr::InvalidAddressError, ArgumentError
        raise Error.new(
          reason_code: "unsafe_destination",
          evidence: { denial_stage: "address_parse", destination_port: safe_port(port) }
        ), cause: nil
      end

      def approve_port!(port)
        normalized_port = Integer(port)
        return normalized_port if @allowed_ports.include?(normalized_port)

        raise Error.new(
          reason_code: "unsafe_destination",
          evidence: { denial_stage: "port_policy", destination_port: normalized_port }
        )
      rescue ArgumentError, TypeError
        raise Error.new(
          reason_code: "unsafe_destination",
          evidence: { denial_stage: "port_policy", destination_port: safe_port(port) }
        ), cause: nil
      end

      private

      def parse_address(value)
        raise IPAddr::InvalidAddressError, "zone identifiers are forbidden" if value.to_s.include?("%")

        address = IPAddr.new(value.to_s)
        address = address.native if address.ipv4_mapped?
        address
      end

      def blocked?(address)
        if address.ipv4?
          !member_of?(address, IPV4_ALLOWED_SPECIAL_NETWORKS) &&
            member_of?(address, IPV4_BLOCKED_NETWORKS)
        else
          !IPV6_GLOBAL_UNICAST.include?(address) || (
            !member_of?(address, IPV6_ALLOWED_SPECIAL_NETWORKS) &&
              member_of?(address, IPV6_BLOCKED_NETWORKS)
          )
        end
      end

      def member_of?(address, networks)
        networks.any? { |network| network.include?(address) }
      end

      def provenance(addresses, port)
        ipv4_count = addresses.count(&:ipv4?)
        {
          address_count: addresses.length,
          ipv4_address_count: ipv4_count,
          ipv6_address_count: addresses.length - ipv4_count,
          destination_port: port,
          address_policy_version: POLICY_VERSION
        }
      end

      def empty_provenance(port)
        provenance([], port)
      end

      def safe_port(value)
        Integer(value).clamp(0, 65_535)
      rescue ArgumentError, TypeError
        0
      end
    end
  end
end
