# frozen_string_literal: true

require "digest"

module Crawling
  class RetrieveRobots
    ALLOWED_CONTENT_TYPES = [ "text/plain" ].freeze

    def initialize(client: nil, clock: -> { Time.current })
      @client = client
      @clock = clock
    end

    def call(origin:)
      canonical = Properties::Public.canonical_origin(origin: origin.respond_to?(:origin) ? origin.origin : origin)
      source_url = "#{canonical.origin}/robots.txt"
      response = client.fetch_public_redirects(
        origin: canonical.origin,
        url: source_url,
        allowed_content_types: ALLOWED_CONTENT_TYPES,
        user_agent: CrawlerIdentity.http_user_agent
      )
      from_response(response, source_url)
    rescue Shared::Public::NetworkSafetyError => error
      from_error(error, source_url)
    end

    private

    def from_response(response, source_url)
      status = Integer(response.fetch(:status))
      body = response.fetch(:body).to_s.b
      retrieval_status = if status.between?(200, 299)
        "fetched"
      elsif status.between?(400, 499)
        "unavailable"
      else
        "unreachable"
      end
      RobotsRetrieval.new(
        status: retrieval_status,
        http_status: status,
        retrieved_at: @clock.call,
        artifact_sha256: Digest::SHA256.hexdigest(body),
        source_url: source_url,
        final_url: response.fetch(:final_url),
        redirect_count: response.fetch(:redirect_count),
        error_code: retrieval_status == "unreachable" ? "http_unreachable" : nil,
        body: body
      )
    rescue ArgumentError, KeyError, TypeError
      RobotsRetrieval.new(
        status: "malformed", retrieved_at: @clock.call, source_url: source_url,
        error_code: "malformed_response", body: ""
      )
    end

    def from_error(error, source_url)
      status = case error.reason_code
      when "response_too_large" then "oversized"
      when "content_type_rejected", "malformed_response" then "malformed"
      else "unreachable"
      end
      RobotsRetrieval.new(
        status: status,
        http_status: error.evidence[:status_code],
        retrieved_at: @clock.call,
        source_url: source_url,
        redirect_count: error.evidence.fetch(:redirect_count, 0),
        error_code: error.reason_code,
        body: ""
      )
    end

    def client
      @client ||= begin
        settings = Rails.application.config.x.searchops
        Shared::Public.safe_http_client(
          dns_timeout: settings.fetch(:crawler_robots_dns_timeout),
          open_timeout: settings.fetch(:crawler_robots_open_timeout),
          read_timeout: settings.fetch(:crawler_robots_read_timeout),
          max_response_bytes: settings.fetch(:crawler_robots_max_response_bytes),
          max_redirects: settings.fetch(:crawler_robots_max_redirects)
        )
      end
    end
  end
end
