# frozen_string_literal: true

require "digest"

module Crawling
  class PreflightOrigin
    ALLOWED_CONTENT_TYPES = %w[
      text/html application/xhtml+xml text/plain application/json application/xml text/xml
    ].freeze

    def initialize(client: nil, clock: -> { Time.current })
      @client = client
      @clock = clock
    end

    def call(environment:)
      response = client.fetch_exact(
        origin: environment.origin.origin,
        url: "#{environment.origin.origin}/",
        allowed_content_types: ALLOWED_CONTENT_TYPES,
        approved_redirect_origins: []
      )
      status = Integer(response.fetch(:status))
      raise TargetUnavailable if status >= 500

      PreflightResult.new(
        checked_at: @clock.call,
        status_code: status,
        destination_digest: Digest::SHA256.hexdigest(response.fetch(:final_origin).to_s),
        redirect_count: response.fetch(:redirect_count)
      )
    rescue Shared::Public::NetworkSafetyError => error
      if error.reason_code.in?(%w[unsafe_destination redirect_rejected redirect_limit])
        raise TargetUnsafe.new(reason_code: "scan_target_#{error.reason_code}"), cause: nil
      end

      raise TargetUnavailable.new(reason_code: "scan_preflight_#{error.reason_code}"), cause: nil
    rescue KeyError, ArgumentError, TypeError
      raise TargetUnavailable.new(reason_code: "scan_preflight_malformed_response"), cause: nil
    end

    private

    def client
      @client ||= begin
        settings = Rails.application.config.x.searchops
        Shared::Public.safe_http_client(
          dns_timeout: settings.fetch(:verification_http_dns_timeout),
          open_timeout: settings.fetch(:verification_http_open_timeout),
          read_timeout: settings.fetch(:verification_http_read_timeout),
          max_response_bytes: settings.fetch(:verification_http_max_response_bytes),
          max_redirects: settings.fetch(:verification_http_max_redirects)
        )
      end
    end
  end
end
