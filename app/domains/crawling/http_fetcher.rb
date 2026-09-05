# frozen_string_literal: true

require "digest"

module Crawling
  class HttpFetcher
    REDIRECT_STATUSES = [ 301, 302, 303, 307, 308 ].freeze
    TRANSIENT_STATUSES = [ 408, 425, 429, 500, 502, 503, 504 ].freeze
    TRANSIENT_ERRORS = %w[
      dns_failure timeout connect_timeout tls_timeout header_timeout body_timeout
      total_timeout tls_protocol transport_failure
    ].freeze
    REJECTED_ERRORS = %w[
      unsafe_destination redirect_rejected redirect_limit header_too_large response_too_large
      decompression_limit unsupported_content_encoding malformed_response content_type_rejected
    ].freeze
    STRONG_SNIFFED_KINDS = %w[html xml json pdf image binary].freeze

    class NullSink
      def write(_chunk); end
      def finish = nil
      def abort; end
    end

    def initialize(destination_policy: nil, transport: nil, limits: nil, max_redirects: nil,
      safe_retries: nil, retry_base_delay: nil, retry_max_delay: nil,
      monotonic_clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
      retry_waiter: nil, recorder: HttpFetchRecorder.new)
      settings = Rails.application.config.x.searchops
      @destination_policy = destination_policy || Shared::Public.destination_policy(
        dns_timeout: settings.fetch(:crawler_dns_timeout)
      )
      @transport = transport || Shared::Public.pinned_http_transport
      @limits = limits || default_limits(settings)
      @max_redirects = Integer(max_redirects || settings.fetch(:crawler_max_redirects))
      @safe_retries = Integer(safe_retries || settings.fetch(:crawler_safe_retries))
      @retry_base_delay = Float(retry_base_delay || settings.fetch(:crawler_retry_base_delay))
      @retry_max_delay = Float(retry_max_delay || settings.fetch(:crawler_retry_max_delay))
      @clock = monotonic_clock
      @retry_waiter = retry_waiter || method(:wait_with_cancellation)
      @recorder = recorder
      valid = @max_redirects.between?(0, 20) && @safe_retries.between?(0, 5) &&
        @retry_base_delay.between?(0.1, 10) && @retry_max_delay.between?(@retry_base_delay, 30) &&
        @retry_waiter.respond_to?(:call) && @recorder.respond_to?(:call)
      raise ArgumentError, "HTTP fetcher limits are invalid" unless valid
    end

    def call(url:, method: :get, approved_redirect_origins: nil, contact_url: nil,
      sink_factory: -> { NullSink.new }, cancellation: -> { false })
      request = normalize_request(
        url: url,
        method: method,
        approved_redirect_origins: approved_redirect_origins,
        contact_url: contact_url,
        sink_factory: sink_factory,
        cancellation: cancellation
      )
      execute(
        initial: request.fetch(:initial),
        redirect_policy: request.fetch(:redirect_policy),
        method: request.fetch(:method),
        user_agent: request.fetch(:user_agent),
        sink_factory: sink_factory,
        cancellation: cancellation
      )
    end

    private

    def normalize_request(url:, method:, approved_redirect_origins:, contact_url:, sink_factory:, cancellation:)
      raise ArgumentError unless sink_factory.respond_to?(:call) && cancellation.respond_to?(:call)

      verb = method.to_s.downcase.to_sym
      raise ArgumentError unless verb.in?(%i[get head])

      initial = Shared::Public.http_target(url: url)
      approved_origins = normalize_redirect_origins(initial.origin, approved_redirect_origins)
      {
        initial: initial,
        redirect_policy: Shared::Public.public_redirect_policy(
          origin: initial.origin,
          url: initial.url,
          approved_redirect_origins: approved_origins
        ),
        method: verb,
        user_agent: CrawlerIdentity.http_user_agent(
          contact_url: contact_url || CrawlerIdentity.default_contact_url
        )
      }.freeze
    rescue Shared::Public::NetworkSafetyError
      raise
    rescue ArgumentError, KeyError, TypeError
      raise ArgumentError, "HTTP fetch request is invalid", cause: nil
    end

    def execute(initial:, redirect_policy:, method:, user_agent:, sink_factory:, cancellation:)
      started = @clock.call
      target = initial
      hops = []
      retries = 0
      redirects = 0
      final_response = nil
      final_artifact = nil
      failure_category = nil
      outcome = nil

      loop do
        final_response = nil
        provenance = nil
        if canceled?(cancellation)
          failure_category = "scan_canceled"
          outcome = "canceled"
          break
        end

        sink = sink_factory.call
        validate_sink!(sink)
        hop_started = @clock.call
        destination = @destination_policy.authorize_target!(target: target)
        provenance = destination.provenance.as_json
        response = @transport.request(
          destination: destination,
          method: method,
          limits: remaining_limits(started),
          user_agent: user_agent,
          sink: sink,
          cancellation: cancellation
        )
        final_response = response

        if REDIRECT_STATUSES.include?(response.status)
          begin
            next_target = redirect_target(redirect_policy, target, response)
          rescue Shared::Public::NetworkSafetyError => error
            abort_sink(sink)
            failure_category = error.reason_code
            outcome = "rejected"
            hops << response_hop(
              hops, target, retries, redirects, response, provenance,
              "rejected", failure_category, nil, hop_started
            )
            break
          end
          redirects += 1
          if redirects > @max_redirects
            abort_sink(sink)
            hops << response_hop(
              hops, target, retries, redirects - 1, response, provenance,
              "rejected", "redirect_limit", nil, hop_started
            )
            failure_category = "redirect_limit"
            outcome = "rejected"
            break
          end
          abort_sink(sink)
          hops << response_hop(
            hops, target, retries, redirects - 1, response, provenance,
            "redirect", nil, next_target.url, hop_started
          )
          target = next_target
          next
        end

        if retryable_status?(response, retries)
          abort_sink(sink)
          retries += 1
          hops << response_hop(
            hops, target, retries - 1, redirects, response, provenance,
            "retry", "http_#{response.status}", nil, hop_started
          )
          if (wait_failure = wait_for_retry(retries, response.headers["retry-after"], started, cancellation))
            failure_category = wait_failure
            outcome = wait_failure == "scan_canceled" ? "canceled" : "failed"
            break
          end
          next
        end

        metadata = normalize_metadata(response)
        mismatch = misleading_content_type?(metadata.fetch(:media_type), response.sniffed_kind)
        if mismatch
          abort_sink(sink)
          failure_category = "content_type_mismatch"
          outcome = "rejected"
        else
          final_artifact = finish_sink(sink)
          outcome = response.status.between?(200, 299) ? "succeeded" : "http_error"
          failure_category = outcome == "http_error" ? "http_#{response.status}" : nil
        end
        hops << response_hop(
          hops, target, retries, redirects, response, provenance,
          outcome.in?(%w[succeeded http_error]) ? "response" : outcome,
          failure_category, nil, hop_started
        )
        break
      rescue Shared::Public::NetworkSafetyError => error
        abort_sink(sink)
        if retryable_error?(error, retries)
          retries += 1
          hops << failure_hop(
            hops, target, retries - 1, redirects, error.reason_code, hop_started,
            outcome: "retry", provenance: provenance
          )
          if (wait_failure = wait_for_retry(retries, nil, started, cancellation))
            failure_category = wait_failure
            outcome = wait_failure == "scan_canceled" ? "canceled" : "failed"
            break
          end
          next
        end

        failure_category = error.reason_code == "canceled" ? "scan_canceled" : error.reason_code
        outcome = if error.reason_code == "canceled"
          "canceled"
        elsif REJECTED_ERRORS.include?(error.reason_code)
          "rejected"
        else
          "failed"
        end
        hops << failure_hop(
          hops, target, retries, redirects, failure_category, hop_started, provenance: provenance
        )
        break
      end

      result = build_result(
        initial: initial,
        target: target,
        method: method,
        response: final_response,
        outcome: outcome,
        failure_category: failure_category,
        retries: retries,
        redirects: redirects,
        hops: hops,
        artifact: final_artifact,
        started: started
      )
      @recorder.call(result)
      result
    end

    def build_result(initial:, target:, method:, response:, outcome:, failure_category:, retries:, redirects:,
      hops:, artifact:, started:)
      metadata = response ? normalize_metadata(response) : empty_metadata
      HttpFetchResult.new(
        method: method,
        requested_url: initial.url,
        final_url: target.url,
        outcome: outcome,
        failure_category: failure_category,
        status: response&.status,
        response_headers: response&.headers || {},
        header_bytes: response&.header_bytes || 0,
        compressed_bytes: response&.compressed_bytes || 0,
        decoded_bytes: response&.decoded_bytes || 0,
        body_sha256: response&.body_sha256 || Digest::SHA256.hexdigest(""),
        sniffed_kind: response&.sniffed_kind || "empty",
        request_count: hops.length,
        retry_count: retries,
        redirect_count: redirects,
        duration_ms: milliseconds(@clock.call - started),
        hops: hops.freeze,
        artifact: artifact,
        **metadata
      )
    end

    def response_hop(hops, target, retries, redirects, response, provenance, outcome, category,
      location_url, started)
      HttpFetchHop.new(
        sequence: hops.length + 1,
        attempt_number: retries + 1,
        redirect_index: redirects,
        requested_url: target.url,
        status: response.status,
        location_url: location_url,
        outcome: outcome,
        failure_category: category,
        resolution_provenance: provenance,
        duration_ms: milliseconds(@clock.call - started),
        header_bytes: response.header_bytes,
        compressed_bytes: response.compressed_bytes,
        decoded_bytes: response.decoded_bytes
      )
    end

    def failure_hop(hops, target, retries, redirects, category, started = nil, outcome: nil, provenance: nil)
      hop_outcome = outcome || failure_hop_outcome(category)
      HttpFetchHop.new(
        sequence: hops.length + 1,
        attempt_number: retries + 1,
        redirect_index: redirects,
        requested_url: target.url,
        outcome: hop_outcome,
        failure_category: category,
        resolution_provenance: provenance,
        duration_ms: started ? milliseconds(@clock.call - started) : 0
      )
    end

    def failure_hop_outcome(category)
      return "canceled" if category.in?(%w[scan_canceled canceled])
      return "rejected" if REJECTED_ERRORS.include?(category)

      "failed"
    end

    def redirect_target(policy, current, response)
      location = response.headers["location"]
      raise Shared::Public::NetworkSafetyError.new(
        reason_code: "redirect_rejected",
        evidence: { denial_stage: "redirect_policy" }
      ) if location.blank?

      policy.redirect(current: current, location: location)
    end

    def normalize_redirect_origins(initial_origin, values)
      candidates = values.nil? ? [ initial_origin ] : Array(values)
      normalized = candidates.map do |value|
        target = Shared::Public.http_target(url: "#{value.to_s.delete_suffix("/")}/")
        raise ArgumentError, "redirect origin is invalid" unless target.request_uri == "/"

        target.origin
      end
      normalized << initial_origin
      normalized.uniq.freeze
    end

    def normalize_metadata(response)
      raw = response.headers.fetch("content-type", "")
      parts = raw.split(";")
      media_type = parts.shift.to_s.strip.downcase
      media_type = nil unless valid_media_type?(media_type)
      charset = parts.filter_map do |parameter|
        name, value = parameter.split("=", 2).map { |item| item.to_s.strip }
        next unless name.casecmp?("charset") && value.present?

        candidate = value.delete_prefix('"').delete_suffix('"').downcase
        candidate if candidate.match?(/\A[a-z0-9._+\-]{1,64}\z/)
      end.first
      encoding = response.headers.fetch("content-encoding", "identity").downcase
      encoding = "identity" if encoding.blank?
      { media_type: media_type, charset: charset, content_encoding: encoding }
    end

    def empty_metadata
      { media_type: nil, charset: nil, content_encoding: "identity" }
    end

    def misleading_content_type?(media_type, sniffed_kind)
      return false if sniffed_kind == "empty" || media_type.nil? || media_type == "application/octet-stream"
      return false unless STRONG_SNIFFED_KINDS.include?(sniffed_kind)

      expected = if media_type.in?(%w[text/html application/xhtml+xml])
        %w[html xml]
      elsif media_type == "image/svg+xml"
        [ "xml" ]
      elsif media_type.end_with?("+xml") || media_type.in?(%w[application/xml text/xml])
        [ "xml" ]
      elsif media_type.end_with?("+json") || media_type == "application/json"
        [ "json" ]
      elsif media_type == "application/pdf"
        [ "pdf" ]
      elsif media_type.start_with?("image/")
        [ "image" ]
      elsif media_type.start_with?("text/")
        %w[text html xml json]
      else
        return false
      end
      !expected.include?(sniffed_kind)
    end

    def valid_media_type?(value)
      value.match?(/\A[a-z0-9!#$&^_.+\-]{1,64}\/[a-z0-9!#$&^_.+\-]{1,64}\z/)
    end

    def retryable_status?(response, retries)
      retries < @safe_retries && TRANSIENT_STATUSES.include?(response.status) &&
        retry_after(response.headers["retry-after"]).then { |value| value.nil? || value <= @retry_max_delay }
    end

    def retryable_error?(error, retries)
      retries < @safe_retries && TRANSIENT_ERRORS.include?(error.reason_code)
    end

    def wait_for_retry(retries, retry_after_header, started, cancellation)
      return "scan_canceled" if canceled?(cancellation)

      delay = retry_after(retry_after_header) || [ @retry_base_delay * (2**(retries - 1)), @retry_max_delay ].min
      return "total_timeout" if elapsed(started) + delay >= @limits.total_timeout

      @retry_waiter.call(delay, cancellation)
      "scan_canceled" if canceled?(cancellation)
    end

    def retry_after(value)
      candidate = value.to_s.strip
      return if candidate.blank? || !candidate.match?(/\A[0-9]{1,3}\z/)

      Integer(candidate)
    end

    def wait_with_cancellation(delay, cancellation)
      deadline = @clock.call + delay
      loop do
        return if canceled?(cancellation)

        remaining = deadline - @clock.call
        return unless remaining.positive?

        sleep([ remaining, 0.1 ].min)
      end
    end

    def remaining_limits(started)
      remaining = @limits.total_timeout - elapsed(started)
      raise Shared::Public::NetworkSafetyError.new(reason_code: "total_timeout") if remaining < 0.1

      @limits.with_total_timeout(remaining)
    end

    def elapsed(started)
      @clock.call - started
    end

    def canceled?(cancellation)
      cancellation.call == true
    end

    def validate_sink!(sink)
      raise ArgumentError, "HTTP body sink is invalid" unless
        sink.respond_to?(:write) && sink.respond_to?(:finish) && sink.respond_to?(:abort)
    end

    def finish_sink(sink)
      sink.finish
    end

    def abort_sink(sink)
      sink&.abort
    rescue StandardError
      nil
    end

    def default_limits(settings)
      Shared::Public.http_transport_limits(
        connect_timeout: settings.fetch(:crawler_connect_timeout),
        tls_timeout: settings.fetch(:crawler_tls_timeout),
        header_timeout: settings.fetch(:crawler_header_timeout),
        body_timeout: settings.fetch(:crawler_read_timeout),
        total_timeout: settings.fetch(:crawler_total_timeout),
        max_header_bytes: settings.fetch(:crawler_max_header_bytes),
        max_body_bytes: settings.fetch(:crawler_max_response_bytes),
        max_decompressed_bytes: settings.fetch(:crawler_max_decompressed_bytes),
        max_decompression_ratio: settings.fetch(:crawler_max_decompression_ratio)
      )
    end

    def milliseconds(seconds)
      (seconds * 1000).round.clamp(0, 600_000)
    end
  end
end
