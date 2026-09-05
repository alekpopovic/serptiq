# frozen_string_literal: true

module Crawling
  SitemapRetrieval = Data.define(
    :status, :http_status, :retrieved_at, :artifact_sha256, :source_url, :final_url,
    :redirect_count, :content_type, :error_code, :body
  ) do
    STATUSES = %w[fetched unavailable unreachable oversized malformed].freeze
    ERROR_PATTERN = /\A[a-z][a-z0-9_]{0,63}\z/

    def initialize(status:, retrieved_at:, source_url:, body:, http_status: nil,
      artifact_sha256: nil, final_url: nil, redirect_count: 0, content_type: nil, error_code: nil)
      normalized_status = status.to_s
      normalized_body = body.to_s.b
      normalized_error = error_code&.to_s
      raise ArgumentError, "sitemap retrieval is invalid" unless
        STATUSES.include?(normalized_status) &&
          (http_status.nil? || Integer(http_status).between?(100, 599)) &&
          Integer(redirect_count).between?(0, 5) &&
          (normalized_error.nil? || ERROR_PATTERN.match?(normalized_error))

      super(
        status: normalized_status.freeze,
        http_status: http_status.nil? ? nil : Integer(http_status),
        retrieved_at: retrieved_at,
        artifact_sha256: artifact_sha256&.to_s&.freeze,
        source_url: source_url.to_s.freeze,
        final_url: final_url&.to_s&.freeze,
        redirect_count: Integer(redirect_count),
        content_type: content_type&.to_s&.freeze,
        error_code: normalized_error&.freeze,
        body: normalized_body.freeze
      )
      freeze
    end

    def accepted_response?
      !http_status.nil?
    end
  end
end
