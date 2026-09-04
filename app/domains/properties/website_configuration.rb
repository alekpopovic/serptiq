# frozen_string_literal: true

module Properties
  WebsiteConfiguration = Data.define(
    :origin, :display_origin, :scheme, :host, :display_host, :port
  ) do
    def initialize(origin:)
      value = CanonicalOrigin.new(origin: origin)
      super(**value.to_h)
      freeze
    end

    def identifier
      origin
    end

    def database_attributes
      { origin: origin, scheme: scheme, host: host, port: port }
    end

    def same_origin?(other)
      CanonicalOrigin.new(origin: origin).same_origin?(other)
    end

    def host_or_subdomain?(candidate_host)
      CanonicalOrigin.new(origin: origin).host_or_subdomain?(candidate_host)
    end
  end
end
