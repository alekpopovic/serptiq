# frozen_string_literal: true

module Verification
  module CanonicalRedirectOrigins
    DEFAULT_PORTS = { "http" => 80, "https" => 443 }.freeze

    module_function

    def for(origin)
      source = Properties::Public.canonical_origin(origin: origin)
      candidates = []
      candidates << build(scheme: "https", host: source.host, port: 443) if source.scheme == "http"
      variant_host = source.host.start_with?("www.") ? source.host.delete_prefix("www.") : "www.#{source.host}"
      candidates << build(scheme: source.scheme, host: variant_host, port: source.port)
      candidates << build(scheme: "https", host: variant_host, port: 443) if source.scheme == "http"
      candidates.compact.map(&:origin).reject { |candidate| candidate == source.origin }.uniq.freeze
    end

    def build(scheme:, host:, port:)
      default_port = DEFAULT_PORTS.fetch(scheme)
      raw = "#{scheme}://#{host}"
      raw = "#{raw}:#{port}" unless port == default_port
      Properties::Public.canonical_origin(origin: raw)
    rescue ArgumentError
      nil
    end
    private_class_method :build
  end
end
