# frozen_string_literal: true

require "ipaddr"

module Shared
  module NetworkSafety
    ApprovedDestination = Data.define(:target, :ip_addresses, :port, :provenance) do
      def initialize(target:, ip_addresses:, port:, provenance:)
        raise ArgumentError, "approved target is invalid" unless target.is_a?(HttpTarget)

        parsed = Array(ip_addresses).map { |value| IPAddr.new(value.to_s) }
        addresses = parsed.map(&:to_s).uniq.freeze
        normalized_port = Integer(port)
        ipv4_count = parsed.count(&:ipv4?)
        valid = addresses.any? && normalized_port == target.port &&
          provenance.is_a?(ResolutionProvenance) && provenance.address_count == addresses.length &&
          provenance.ipv4_address_count == ipv4_count &&
          provenance.ipv6_address_count == parsed.length - ipv4_count &&
          provenance.destination_port == normalized_port
        raise ArgumentError, "approved destination is invalid" unless valid

        super(target: target, ip_addresses: addresses, port: normalized_port, provenance: provenance)
        freeze
      rescue IPAddr::InvalidAddressError
        raise ArgumentError, "approved destination is invalid", cause: nil
      end

      def connection_ip
        ip_addresses.first
      end

      def as_json(*)
        provenance.as_json
      end

      def inspect
        "#<#{self.class.name} address_count=#{ip_addresses.length} port=#{port}>"
      end

      alias_method :to_s, :inspect
    end
  end
end
