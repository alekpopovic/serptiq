# frozen_string_literal: true

require "addressable/idna"
require "addressable/uri"
require "ipaddr"

module Shared
  module NetworkSafety
    HttpTarget = Data.define(:url, :origin, :scheme, :host, :port, :request_uri, :path) do
      DEFAULT_PORTS = { "http" => 80, "https" => 443 }.freeze
      LABEL_PATTERN = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/

      def initialize(url:)
        raw = url.to_s
        reject_ambiguous!(raw)
        uri = Addressable::URI.parse(raw)
        scheme = uri.scheme.to_s.downcase
        raise ArgumentError, "unsupported URL scheme" unless DEFAULT_PORTS.key?(scheme)
        raise ArgumentError, "URL credentials are forbidden" if uri.user.present? || uri.password.present?
        raise ArgumentError, "URL fragment is forbidden" if uri.fragment.present?

        host = normalize_host(uri.host)
        port = normalize_port(uri.port, scheme)
        path = uri.path.presence || "/"
        raise ArgumentError, "URL path is invalid" unless path.start_with?("/")

        request_uri = path.dup
        request_uri << "?#{uri.query}" if uri.query.present?
        origin = build_origin(scheme, host, port)
        canonical_url = "#{origin}#{request_uri}"
        super(
          url: canonical_url.freeze,
          origin: origin.freeze,
          scheme: scheme.freeze,
          host: host.freeze,
          port: port,
          request_uri: request_uri.freeze,
          path: path.freeze
        )
        freeze
      rescue ArgumentError
        raise
      rescue StandardError => error
        raise ArgumentError, "URL is invalid", cause: error
      end

      private

      def reject_ambiguous!(raw)
        raise ArgumentError, "URL is invalid" if raw.blank? || raw != raw.strip || raw.match?(/[\u0000-\u0020\\]/)

        authority = raw.split("#", 2).first.to_s.split("?", 2).first.to_s
          .split("://", 2).last.to_s.split("/", 2).first.to_s
        raise ArgumentError, "URL port is invalid" if authority.end_with?(":")
      end

      def normalize_host(value)
        raw = value.to_s.delete_suffix(".").downcase
        raise ArgumentError, "URL host is invalid" if raw.blank? || ip_literal?(raw)

        ascii = Addressable::IDNA.to_ascii(raw).downcase
        labels = ascii.split(".", -1)
        valid = ascii.bytesize <= 253 && labels.length >= 2 && labels.all? do |label|
          label.bytesize.between?(1, 63) && LABEL_PATTERN.match?(label)
        end
        valid &&= !labels.last.match?(/\A(?:\d+|0x[0-9a-f]+)\z/i)
        raise ArgumentError, "URL host is invalid" unless valid

        ascii
      end

      def ip_literal?(value)
        IPAddr.new(value.delete_prefix("[").delete_suffix("]"))
        true
      rescue IPAddr::InvalidAddressError
        false
      end

      def normalize_port(value, scheme)
        port = value || DEFAULT_PORTS.fetch(scheme)
        raise ArgumentError, "URL port is invalid" unless port.is_a?(Integer) && port.between?(1, 65_535)

        port
      end

      def build_origin(scheme, host, port)
        base = "#{scheme}://#{host}"
        port == DEFAULT_PORTS.fetch(scheme) ? base : "#{base}:#{port}"
      end
    end
  end
end
