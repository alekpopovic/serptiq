# frozen_string_literal: true

module Shared
  module NetworkSafety
    TransportLimits = Data.define(
      :connect_timeout, :tls_timeout, :header_timeout, :body_timeout, :total_timeout,
      :max_header_bytes, :max_body_bytes, :max_decompressed_bytes, :max_decompression_ratio
    ) do
      def initialize(connect_timeout:, tls_timeout:, header_timeout:, body_timeout:, total_timeout:,
        max_header_bytes:, max_body_bytes:, max_decompressed_bytes:, max_decompression_ratio:)
        durations = [ connect_timeout, tls_timeout, header_timeout, body_timeout, total_timeout ]
          .map { |value| Float(value) }
        sizes = [ max_header_bytes, max_body_bytes, max_decompressed_bytes ]
          .map { |value| Integer(value) }
        ratio = Float(max_decompression_ratio)
        valid = durations.take(2).all? { |value| value.between?(0.1, 60) } &&
          durations.fetch(2).between?(0.1, 60) && durations.fetch(3).between?(0.1, 300) &&
          durations.fetch(4).between?(0.1, 600) && sizes.fetch(0).between?(1024, 262_144) &&
          sizes.fetch(1).between?(1024, 104_857_600) &&
          sizes.fetch(2).between?(1024, 524_288_000) && ratio.between?(1, 1000)
        raise ArgumentError, "HTTP transport limits are invalid" unless valid

        super(
          connect_timeout: durations.fetch(0),
          tls_timeout: durations.fetch(1),
          header_timeout: durations.fetch(2),
          body_timeout: durations.fetch(3),
          total_timeout: durations.fetch(4),
          max_header_bytes: sizes.fetch(0),
          max_body_bytes: sizes.fetch(1),
          max_decompressed_bytes: sizes.fetch(2),
          max_decompression_ratio: ratio
        )
        freeze
      end

      def with_total_timeout(value)
        self.class.new(**to_h.merge(total_timeout: value))
      end
    end
  end
end
