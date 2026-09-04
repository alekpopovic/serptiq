# frozen_string_literal: true

require "addressable/idna"
require "addressable/uri"
require "ipaddr"

module Properties
  CanonicalOrigin = Data.define(:origin, :display_origin, :scheme, :host, :display_host, :port) do
    SCHEMES = { "http" => 80, "https" => 443 }.freeze
    INTERNAL_SUFFIXES = %w[localhost local localdomain internal lan home corp].freeze
    LABEL_PATTERN = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/

    def initialize(origin:)
      raw = origin.to_s.strip
      reject_ambiguous_input!(raw)
      uri = Addressable::URI.parse(raw)
      normalized_scheme = uri.scheme.to_s.downcase
      raise ArgumentError, "origin must use HTTP or HTTPS" unless SCHEMES.key?(normalized_scheme)
      raise ArgumentError, "origin must not contain credentials" if uri.user.present? || uri.password.present?
      raise ArgumentError, "origin must not contain a path query or fragment" unless
        uri.path.in?([ "", "/" ]) && uri.query.nil? && uri.fragment.nil?

      network_host, unicode_host = normalize_host(uri.host)
      effective_port = normalize_port(uri.port, normalized_scheme)
      canonical = build_origin(normalized_scheme, network_host, effective_port)
      display = build_origin(normalized_scheme, unicode_host, effective_port)
      super(
        origin: canonical.freeze,
        display_origin: display.freeze,
        scheme: normalized_scheme.freeze,
        host: network_host.freeze,
        display_host: unicode_host.freeze,
        port: effective_port
      )
      freeze
    rescue ArgumentError
      raise
    rescue StandardError => error
      raise ArgumentError, "origin is invalid", cause: error
    end

    def identifier
      origin
    end

    def same_origin?(other)
      candidate = other.is_a?(CanonicalOrigin) ? other : self.class.new(origin: other)
      origin == candidate.origin
    end

    def host_or_subdomain?(candidate_host)
      candidate, = normalize_host(candidate_host)
      candidate == host || candidate.end_with?(".#{host}")
    end

    private

    def reject_ambiguous_input!(raw)
      raise ArgumentError, "origin is invalid" if raw.blank? || raw.match?(/[\u0000-\u0020\\]/)

      authority = raw.split("://", 2).last.to_s.split(/[\/?#]/, 2).first.to_s
      raise ArgumentError, "origin port is invalid" if authority.end_with?(":")
    end

    def normalize_host(raw_host)
      original = raw_host.to_s.unicode_normalize(:nfc)
      raise ArgumentError, "origin host is invalid" if original.blank?
      raise ArgumentError, "origin must use a hostname, not an IP address" if ip_literal?(original)
      raise ArgumentError, "origin host has an invalid trailing dot" if original.end_with?("..")

      original = original.delete_suffix(".").downcase
      ascii = Addressable::IDNA.to_ascii(original).downcase
      validate_ascii_host!(ascii)
      unicode = Addressable::IDNA.to_unicode(ascii).unicode_normalize(:nfc).downcase
      raise ArgumentError, "origin host IDNA form is unstable" unless
        Addressable::IDNA.to_ascii(unicode).downcase == ascii

      [ ascii, unicode ]
    rescue ArgumentError
      raise
    rescue StandardError => error
      raise ArgumentError, "origin host is invalid", cause: error
    end

    def validate_ascii_host!(ascii)
      labels = ascii.split(".", -1)
      raise ArgumentError, "origin must use a qualified public hostname" if labels.length < 2
      raise ArgumentError, "origin host is too long" if ascii.bytesize > 253
      raise ArgumentError, "origin host is invalid" unless labels.all? do |label|
        label.bytesize.between?(1, 63) && LABEL_PATTERN.match?(label)
      end
      raise ArgumentError, "private or internal origins are unsupported" if
        INTERNAL_SUFFIXES.include?(labels.last)
      raise ArgumentError, "origin must use a hostname, not an IP address" if
        labels.all? { |label| label.match?(/\A\d+\z/) }
    end

    def ip_literal?(value)
      candidate = value.delete_prefix("[").delete_suffix("]")
      IPAddr.new(candidate)
      true
    rescue IPAddr::InvalidAddressError
      false
    end

    def normalize_port(explicit_port, normalized_scheme)
      port = explicit_port || SCHEMES.fetch(normalized_scheme)
      raise ArgumentError, "origin port is invalid" unless port.is_a?(Integer) && port.between?(1, 65_535)

      port
    end

    def build_origin(normalized_scheme, normalized_host, effective_port)
      value = "#{normalized_scheme}://#{normalized_host}"
      effective_port == SCHEMES.fetch(normalized_scheme) ? value : "#{value}:#{effective_port}"
    end
  end
end
