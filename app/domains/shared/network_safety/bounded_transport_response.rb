# frozen_string_literal: true

module Shared
  module NetworkSafety
    class BoundedTransportResponse < Data.define(
      :status, :headers, :header_bytes, :compressed_bytes, :decoded_bytes,
      :body_sha256, :sniffed_kind, :timings
    )
      HEADER_NAMES = %w[
        cache-control content-encoding content-language content-length content-type etag
        last-modified location retry-after transfer-encoding x-robots-tag
      ].freeze
      SNIFFED_KINDS = %w[empty html xml json pdf image text binary unknown].freeze
      TIMING_NAMES = %i[connect_ms tls_ms header_ms body_ms total_ms].freeze

      def initialize(status:, headers:, header_bytes:, compressed_bytes:, decoded_bytes:,
        body_sha256:, sniffed_kind:, timings:)
        code = Integer(status)
        normalized_headers = headers.to_h.each_with_object({}) do |(name, value), result|
          key = name.to_s.downcase
          next unless HEADER_NAMES.include?(key)

          candidate = value.to_s
          next unless candidate.ascii_only?

          candidate = candidate.dup.force_encoding(Encoding::UTF_8)
          raise ArgumentError, "HTTP response header is invalid" unless
            candidate.valid_encoding? && candidate.bytesize <= 8192 && !candidate.match?(/[\u0000\r\n]/)

          result[key.freeze] = candidate.freeze
        end.freeze
        header_size = Integer(header_bytes)
        compressed_size = Integer(compressed_bytes)
        decoded_size = Integer(decoded_bytes)
        digest = body_sha256.to_s
        kind = sniffed_kind.to_s
        normalized_timings = timings.to_h.transform_keys(&:to_sym).transform_values do |value|
          Integer(value)
        end.slice(*TIMING_NAMES).freeze
        valid = code.between?(100, 599) && header_size.between?(0, 262_144) &&
          compressed_size.between?(0, 104_857_600) && decoded_size.between?(0, 524_288_000) &&
          digest.match?(/\A[0-9a-f]{64}\z/) && SNIFFED_KINDS.include?(kind) &&
          normalized_timings.keys.sort == TIMING_NAMES.sort &&
          normalized_timings.values.all? { |value| value.between?(0, 600_000) }
        raise ArgumentError, "bounded HTTP response is invalid" unless valid

        super(
          status: code,
          headers: normalized_headers,
          header_bytes: header_size,
          compressed_bytes: compressed_size,
          decoded_bytes: decoded_size,
          body_sha256: digest.freeze,
          sniffed_kind: kind.freeze,
          timings: normalized_timings
        )
        freeze
      end

      def inspect
        "#<#{self.class.name} status=#{status} decoded_bytes=#{decoded_bytes}>"
      end
    end
  end
end
