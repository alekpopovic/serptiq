# frozen_string_literal: true

module Shared
  module NetworkSafety
    ResolutionProvenance = Data.define(
      :address_count, :ipv4_address_count, :ipv6_address_count, :destination_port,
      :address_policy_version
    ) do
      def initialize(address_count:, ipv4_address_count:, ipv6_address_count:, destination_port:,
        address_policy_version:)
        counts = [ address_count, ipv4_address_count, ipv6_address_count ].map { |value| Integer(value) }
        port = Integer(destination_port)
        version = address_policy_version.to_s
        valid = counts.all? { |value| value.between?(0, PublicResolver::MAX_ADDRESSES) } &&
          counts.drop(1).sum == counts.first && port.between?(1, 65_535) &&
          version == AddressPolicy::POLICY_VERSION
        raise ArgumentError, "resolution provenance is invalid" unless valid

        super(
          address_count: counts.first,
          ipv4_address_count: counts.second,
          ipv6_address_count: counts.third,
          destination_port: port,
          address_policy_version: version.freeze
        )
        freeze
      end

      def as_json(*)
        to_h.freeze
      end
    end
  end
end
