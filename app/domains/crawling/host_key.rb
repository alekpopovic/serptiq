# frozen_string_literal: true

require "digest"

module Crawling
  class HostKey < Data.define(:scheme, :hostname, :port, :canonical, :digest)
    VERSION = 2
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

    def initialize(url:, digestor: ->(value) { Digest::SHA256.hexdigest(value) })
      target = Shared::Public.http_target(url: url)
      scheme = target.scheme.to_s
      hostname = target.host.to_s
      port = Integer(target.port)
      canonical = "#{scheme}://#{hostname}:#{port}"
      digest = digestor.call("crawl-host:v#{VERSION}:#{canonical}").to_s
      raise ArgumentError, "host key digest is invalid" unless DIGEST_PATTERN.match?(digest)

      super(
        scheme: scheme.freeze,
        hostname: hostname.freeze,
        port: port,
        canonical: canonical.freeze,
        digest: digest.freeze
      )
      freeze
    rescue Shared::Public::NetworkSafetyError
      raise ArgumentError, "host key is invalid", cause: nil
    end

    def inspect
      "#<#{self.class.name} scheme=#{scheme} port=#{port} digest=#{digest.first(12)}>"
    end
  end
end
