# frozen_string_literal: true

module Verification
  SearchConsolePropertyIdentifier = Data.define(:external_identifier, :property_type, :origin, :host) do
    DOMAIN_PREFIX = "sc-domain:"

    def self.parse(value)
      identifier = value.to_s
      raise ArgumentError, "provider property identifier is invalid" unless
        identifier == identifier.strip && identifier.bytesize.between?(1, 2048)

      if identifier.start_with?(DOMAIN_PREFIX)
        host = identifier.delete_prefix(DOMAIN_PREFIX)
        canonical = Properties::Public.canonical_origin(origin: "https://#{host}")
        raise ArgumentError, "domain property identifier is not canonical" unless host == canonical.host

        new(
          external_identifier: identifier.freeze,
          property_type: "domain".freeze,
          origin: nil,
          host: canonical.host.freeze
        ).freeze
      else
        canonical = Properties::Public.canonical_origin(origin: identifier)
        raise ArgumentError, "URL-prefix property identifier must end at the origin root" unless
          identifier == "#{canonical.origin}/"

        new(
          external_identifier: identifier.freeze,
          property_type: "url_prefix".freeze,
          origin: canonical.origin.freeze,
          host: canonical.host.freeze
        ).freeze
      end
    end

    def matches_origin?(candidate)
      normalized = Properties::Public.canonical_origin(origin: candidate)
      property_type == "url_prefix" ? origin == normalized.origin : host == normalized.host
    rescue ArgumentError
      false
    end
  end
end
