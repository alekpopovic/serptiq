# frozen_string_literal: true

module Crawling
  class RobotsRetrieval < Data.define(
    :status, :http_status, :retrieved_at, :artifact_sha256, :source_url, :final_url,
    :redirect_count, :error_code, :body
  )
    STATUSES = %w[fetched unavailable unreachable oversized malformed].freeze
    ERROR_PATTERN = /\A[a-z][a-z0-9_]{0,63}\z/

    def initialize(**attributes)
      status = attributes.fetch(:status).to_s
      raise ArgumentError, "robots retrieval status is invalid" unless STATUSES.include?(status)

      error_code = attributes[:error_code]&.to_s
      raise ArgumentError, "robots retrieval error is invalid" if error_code && !ERROR_PATTERN.match?(error_code)

      super(
        status: status.freeze,
        http_status: attributes[:http_status]&.then { |value| Integer(value) },
        retrieved_at: attributes.fetch(:retrieved_at),
        artifact_sha256: attributes[:artifact_sha256]&.to_s&.freeze,
        source_url: attributes.fetch(:source_url).to_s.freeze,
        final_url: attributes[:final_url]&.to_s&.freeze,
        redirect_count: Integer(attributes.fetch(:redirect_count, 0)),
        error_code: error_code&.freeze,
        body: attributes.fetch(:body, "").to_s.b.freeze
      )
      freeze
    end
  end
end
