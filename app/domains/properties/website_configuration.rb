# frozen_string_literal: true

require "ipaddr"
require "uri"

module Properties
  WebsiteConfiguration = Data.define(:origin, :scheme, :host, :port) do
    HOST_PATTERN = /\A[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?\z/

    def initialize(origin:)
      raw = origin.to_s.strip
      uri = URI.parse(raw)
      scheme = uri.scheme.to_s.downcase
      host = uri.host.to_s.downcase
      raise ArgumentError, "website origin must use HTTP or HTTPS" unless scheme.in?(%w[http https])
      raise ArgumentError, "website origin must not contain credentials" if uri.userinfo.present?
      raise ArgumentError, "website origin must not contain a path query or fragment" unless
        uri.path.in?([ "", "/" ]) && uri.query.nil? && uri.fragment.nil?
      raise ArgumentError, "website origin host is invalid" unless HOST_PATTERN.match?(host)
      begin
        IPAddr.new(host)
        raise ArgumentError, "website origin must use a hostname"
      rescue IPAddr::InvalidAddressError
        nil
      end
      raise ArgumentError, "website origin must use a qualified hostname" unless host.include?(".")

      port = uri.port
      canonical = "#{scheme}://#{host}"
      canonical = "#{canonical}:#{port}" unless (scheme == "http" && port == 80) ||
        (scheme == "https" && port == 443)
      super(origin: canonical.freeze, scheme: scheme.freeze, host: host.freeze, port: port)
      freeze
    rescue URI::InvalidURIError, URI::InvalidComponentError
      raise ArgumentError, "website origin is invalid"
    end

    def identifier
      origin
    end

    def database_attributes
      { origin: origin, scheme: scheme, host: host, port: port }
    end
  end
end
