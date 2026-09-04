# frozen_string_literal: true

module Shared
  module NetworkSafety
    TransportResponse = Data.define(:status, :headers, :body) do
      def initialize(status:, headers:, body:)
        normalized_headers = headers.to_h.transform_keys { |key| key.to_s.downcase }.transform_values(&:to_s).freeze
        super(status: Integer(status), headers: normalized_headers, body: body.to_s.b.freeze)
        freeze
      end
    end
  end
end
