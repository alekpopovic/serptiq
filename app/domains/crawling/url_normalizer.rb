# frozen_string_literal: true

require "addressable/uri"
require "digest"

module Crawling
  class UrlNormalizer
    CURRENT_VERSION = 2
    SUPPORTED_VERSIONS = [ 1, CURRENT_VERSION ].freeze
    MAXIMUM_URL_BYTES = 8192
    RAW_CONTROL_OR_AMBIGUITY = /[\u0000-\u0020\u007f\\]/
    ENCODED_CONTROL = /%(?:0[0-9A-Fa-f]|1[0-9A-Fa-f]|7[Ff])/

    def call(url:, normalization_version: CURRENT_VERSION, query_handling: "all",
      query_parameter_allowlist: [], query_parameter_denylist: [],
      digestor: ->(value) { Digest::SHA256.hexdigest(value) })
      version = Integer(normalization_version)
      raise ArgumentError, "URL normalization version is unsupported" unless SUPPORTED_VERSIONS.include?(version)

      if version == 1
        normalize_v1(
          url,
          query_handling: query_handling,
          allowlist: query_parameter_allowlist,
          denylist: query_parameter_denylist,
          digestor: digestor
        )
      else
        normalize_v2(
          url,
          query_handling: query_handling,
          allowlist: query_parameter_allowlist,
          denylist: query_parameter_denylist,
          digestor: digestor
        )
      end
    rescue ArgumentError
      raise
    rescue StandardError => error
      raise ArgumentError, "URL is invalid", cause: error
    end

    private

    def normalize_v1(url, query_handling:, allowlist:, denylist:, digestor:)
      raise ArgumentError, "version 1 supports unfiltered query identity only" unless
        query_handling.to_s == "all" && Array(allowlist).empty? && Array(denylist).empty?

      target = Shared::Public.http_target(url: url)
      build_value(
        fetch_url: target.url,
        identity_url: target.url,
        target: target,
        path: target.path,
        version: 1,
        digestor: digestor
      )
    end

    def normalize_v2(url, query_handling:, allowlist:, denylist:, digestor:)
      raw = url.to_s
      validate_raw!(raw)
      uri = Addressable::URI.parse(raw)
      validate_authority!(raw, uri)
      target = authority_target(uri)
      path = normalized_path(uri)
      query_policy = UrlQueryPolicy.new(
        handling: query_handling,
        allowlist: allowlist,
        denylist: denylist
      )
      fetch_query, identity_query = query_policy.normalize(uri.query)
      fetch_url = assemble(target.origin, path, fetch_query)
      identity_url = assemble(target.origin, path, identity_query)
      build_value(
        fetch_url: fetch_url,
        identity_url: identity_url,
        target: target,
        path: path,
        version: CURRENT_VERSION,
        digestor: digestor
      )
    end

    def validate_raw!(raw)
      valid = raw.valid_encoding? && raw.bytesize.between?(1, MAXIMUM_URL_BYTES) &&
        raw == raw.strip && !RAW_CONTROL_OR_AMBIGUITY.match?(raw)
      raise ArgumentError, "URL contains ambiguous or control characters" unless valid
    end

    def validate_authority!(raw, uri)
      scheme = uri.scheme.to_s.downcase
      raise ArgumentError, "unsupported URL scheme" unless %w[http https].include?(scheme)
      raise ArgumentError, "URL credentials are forbidden" if uri.user.present? || uri.password.present?
      raise ArgumentError, "URL host is invalid" if uri.host.blank?

      authority = raw.split("#", 2).first.to_s.split("?", 2).first.to_s
        .split("://", 2).last.to_s.split("/", 2).first.to_s
      raise ArgumentError, "URL port is invalid" if authority.end_with?(":")
      if authority.include?(":")
        explicit_port = authority.rpartition(":").last
        port = Integer(explicit_port, exception: false)
        raise ArgumentError, "URL port is invalid" unless
          explicit_port.match?(/\A[0-9]+\z/) && port&.between?(1, 65_535)
      end
      raise ArgumentError, "URL path percent encoding is invalid" if
        uri.path.to_s.match?(/%(?![0-9A-Fa-f]{2})/)
      raise ArgumentError, "encoded control characters are forbidden" if
        uri.path.to_s.match?(ENCODED_CONTROL) || uri.query.to_s.match?(ENCODED_CONTROL)
    end

    def authority_target(uri)
      probe = uri.dup
      probe.fragment = nil
      probe.query = nil
      probe.path = "/"
      Shared::Public.http_target(url: probe.to_s)
    end

    def normalized_path(uri)
      path = uri.path.present? ? uri.normalized_path : "/"
      raise ArgumentError, "URL path is invalid" unless path.start_with?("/") && path.bytesize <= MAXIMUM_URL_BYTES

      path.freeze
    end

    def assemble(origin, path, query)
      value = +"#{origin}#{path}"
      value << "?#{query}" if query
      raise ArgumentError, "normalized URL is too long" if value.bytesize > MAXIMUM_URL_BYTES

      value.freeze
    end

    def build_value(fetch_url:, identity_url:, target:, path:, version:, digestor:)
      identity_digest = digestor.call("crawl-url:v#{version}:#{identity_url}").to_s
      host_digest = digestor.call("crawl-host:v1:#{target.host}").to_s
      unless identity_digest.match?(/\A[0-9a-f]{64}\z/) && host_digest.match?(/\A[0-9a-f]{64}\z/)
        raise ArgumentError, "URL digest is invalid"
      end

      NormalizedUrl.new(
        fetch_url: fetch_url,
        identity_url: identity_url,
        origin: target.origin,
        scheme: target.scheme,
        host: target.host,
        port: target.port,
        path: path,
        normalization_version: version,
        identity_digest: identity_digest,
        host_digest: host_digest
      )
    end
  end
end
