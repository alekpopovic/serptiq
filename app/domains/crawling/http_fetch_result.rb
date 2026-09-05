# frozen_string_literal: true

require "digest"

module Crawling
  class HttpFetchResult < Data.define(
    :method, :requested_url, :final_url, :outcome, :failure_category, :status,
    :media_type, :charset, :content_encoding, :response_headers, :header_bytes,
    :compressed_bytes, :decoded_bytes, :body_sha256, :sniffed_kind, :request_count,
    :retry_count, :redirect_count, :duration_ms, :hops, :artifact
  )
    OUTCOMES = %w[succeeded http_error rejected failed canceled throttled].freeze
    SNIFFED_KINDS = %w[empty html xml json pdf image text binary unknown].freeze
    METHOD_PATTERN = /\A(?:GET|HEAD)\z/
    TOKEN_PATTERN = /\A[a-z0-9!#$&^_.+\-]{1,64}\z/

    def initialize(**attributes)
      method = attributes.fetch(:method).to_s.upcase
      requested_url = attributes.fetch(:requested_url).to_s
      final_url = attributes.fetch(:final_url).to_s
      outcome = attributes.fetch(:outcome).to_s
      category = attributes[:failure_category]&.to_s
      status = attributes[:status]&.then { |value| Integer(value) }
      media_type = attributes[:media_type]&.to_s
      charset = attributes[:charset]&.to_s
      content_encoding = attributes.fetch(:content_encoding, "identity").to_s
      headers = normalize_headers(attributes.fetch(:response_headers, {}))
      sizes = %i[header_bytes compressed_bytes decoded_bytes].to_h do |name|
        [ name, Integer(attributes.fetch(name, 0)) ]
      end
      body_sha256 = attributes.fetch(:body_sha256, Digest::SHA256.hexdigest("")).to_s
      sniffed_kind = attributes.fetch(:sniffed_kind, "empty").to_s
      request_count = Integer(attributes.fetch(:request_count))
      retry_count = Integer(attributes.fetch(:retry_count))
      redirect_count = Integer(attributes.fetch(:redirect_count))
      duration = Integer(attributes.fetch(:duration_ms))
      hops = Array(attributes.fetch(:hops)).freeze
      valid = METHOD_PATTERN.match?(method) && requested_url.bytesize.between?(1, 8192) &&
        final_url.bytesize.between?(1, 8192) && OUTCOMES.include?(outcome) &&
        (category.nil? || HttpFetchHop::CATEGORY_PATTERN.match?(category)) &&
        (status.nil? || status.between?(100, 599)) &&
        (media_type.nil? || valid_media_type?(media_type)) &&
        (charset.nil? || TOKEN_PATTERN.match?(charset)) && TOKEN_PATTERN.match?(content_encoding) &&
        sizes.fetch(:header_bytes).between?(0, 262_144) &&
        sizes.fetch(:compressed_bytes).between?(0, 104_857_600) &&
        sizes.fetch(:decoded_bytes).between?(0, 524_288_000) &&
        body_sha256.match?(/\A[0-9a-f]{64}\z/) &&
        SNIFFED_KINDS.include?(sniffed_kind) &&
        request_count.between?(0, 32) && retry_count.between?(0, 10) && redirect_count.between?(0, 20) &&
        duration.between?(0, 600_000) && hops.length == request_count &&
        hops.all? { |hop| hop.is_a?(HttpFetchHop) }
      raise ArgumentError, "HTTP fetch result is invalid" unless valid

      super(
        method: method.freeze,
        requested_url: requested_url.freeze,
        final_url: final_url.freeze,
        outcome: outcome.freeze,
        failure_category: category&.freeze,
        status: status,
        media_type: media_type&.freeze,
        charset: charset&.freeze,
        content_encoding: content_encoding.freeze,
        response_headers: headers,
        **sizes,
        body_sha256: body_sha256.freeze,
        sniffed_kind: sniffed_kind.freeze,
        request_count: request_count,
        retry_count: retry_count,
        redirect_count: redirect_count,
        duration_ms: duration,
        hops: hops,
        artifact: attributes[:artifact]
      )
      freeze
    end

    def successful?
      outcome == "succeeded"
    end

    def retryable?
      false
    end

    def inspect
      "#<#{self.class.name} outcome=#{outcome} status=#{status || "none"} " \
        "decoded_bytes=#{decoded_bytes} request_count=#{request_count}>"
    end

    private

    def normalize_headers(value)
      value.to_h.each_with_object({}) do |(name, item), result|
        key = name.to_s.downcase
        next unless %w[
          cache-control content-language content-type etag last-modified retry-after x-robots-tag
        ].include?(key)

        candidate = item.to_s
        raise ArgumentError, "HTTP fetch header is invalid" unless
          candidate.valid_encoding? && candidate.bytesize <= 8192 && !candidate.match?(/[\u0000\r\n]/)

        result[key.freeze] = candidate.freeze
      end.freeze
    end

    def valid_media_type?(value)
      type, subtype = value.split("/", 2)
      type && subtype && TOKEN_PATTERN.match?(type) && TOKEN_PATTERN.match?(subtype)
    end
  end
end
