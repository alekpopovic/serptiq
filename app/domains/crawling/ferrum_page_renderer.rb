# frozen_string_literal: true

require "digest"
require "timeout"
require "uri"

module Crawling
  class FerrumPageRenderer
    RENDERER_VERSION = "ferrum-render-1.0".freeze
    INTERNAL_SCHEMES = %w[about data blob].freeze
    MAX_MESSAGES = 100
    MAX_MESSAGE_BYTES = 1024

    def initialize(settings: Rails.application.config.x.searchops, browser_pool: nil,
      destination_policy: nil, monotonic_clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @settings = settings
      @browser_pool = browser_pool || FerrumBrowserPool.new(settings: settings)
      @destination_policy = destination_policy || Shared::Public.destination_policy(
        dns_timeout: settings.fetch(:crawler_dns_timeout)
      )
      @monotonic_clock = monotonic_clock
    end

    def call(url:, screenshot:, canceled: -> { false })
      ensure_render_worker!
      started = @monotonic_clock.call
      result = nil
      Timeout.timeout(@settings.fetch(:browser_timeout)) do
        @browser_pool.with_page do |page|
          result = render(page, url, screenshot, canceled, started)
        end
      end
      result
    rescue Timeout::Error, Ferrum::TimeoutError, Ferrum::ProcessTimeoutError => error
      @browser_pool.recycle
      raise RenderError.new(reason_code: "render_timeout", transient: true), cause: error
    rescue Ferrum::DeadBrowserError, Ferrum::BrowserError, Errno::EPIPE => error
      @browser_pool.recycle
      raise RenderError.new(reason_code: "browser_crashed", transient: true), cause: error
    end

    private

    def render(page, url, screenshot, canceled, started)
      state = network_state
      console_messages = []
      page_errors = []
      subscribe(page, state, console_messages, page_errors)
      page.network.intercept(handle_auth_requests: true)
      page.on(:request) { |request, *_| handle_request(request, state, canceled) }
      page.on(:auth) { |request, *_| request.abort }
      page.on(:dialog) { |dialog, *_| dialog.dismiss }
      page.downloads.set_behavior(save_path: "/tmp", behavior: :deny)
      raise_canceled! if canceled.call

      page.go_to(url)
      page.network.wait_for_idle!(duration: 0.1, timeout: remaining(started))
      raise_network_violation!(state)
      raise_canceled! if canceled.call
      final_url = page.current_url.to_s
      @destination_policy.authorize!(url: final_url)
      dom = page.body.to_s.b
      raise RenderError.new(reason_code: "rendered_dom_too_large") if
        dom.bytesize > HtmlPageExtractor::MAX_HTML_BYTES
      image = screenshot ? page.screenshot(format: "png", encoding: :binary, timeout: remaining(started)) : nil
      provenance = @browser_pool.browser_provenance
      duration_ms = ((@monotonic_clock.call - started) * 1000).round
      traffic = page.network.traffic

      RenderResult.new(
        final_url: final_url,
        dom: dom,
        screenshot: image,
        duration_ms: duration_ms,
        request_count: state.fetch(:request_count),
        response_bytes: state.fetch(:response_bytes),
        console_messages: console_messages,
        page_errors: page_errors,
        network_summary: summarize(traffic, state),
        renderer_version: RENDERER_VERSION,
        ferrum_version: FerrumBrowserPool::FERRUM_VERSION,
        **provenance
      )
    rescue Shared::Public::NetworkSafetyError => error
      raise RenderError.new(reason_code: error.reason_code), cause: error
    end

    def subscribe(page, state, console_messages, page_errors)
      page.on("Network.loadingFinished") do |params|
        state.fetch(:mutex).synchronize do
          state[:response_bytes] += params.fetch("encodedDataLength", 0).to_i
          state[:violation] ||= "render_byte_limit_exceeded" if
            state.fetch(:response_bytes) > @settings.fetch(:browser_max_response_bytes)
        end
      end
      page.on("Runtime.consoleAPICalled") do |params|
        message = params.fetch("args", []).filter_map { |arg| arg["value"] || arg["description"] }.join(" ")
        append_message(console_messages, "#{params['type']}: #{message}")
      end
      page.on("Runtime.exceptionThrown") do |params|
        detail = params.fetch("exceptionDetails", {})
        append_message(page_errors, detail["text"] || detail.dig("exception", "description") || "javascript_error")
      end
    end

    def handle_request(request, state, canceled)
      violation = nil
      state.fetch(:mutex).synchronize do
        state[:request_count] += 1
        violation = "render_request_limit_exceeded" if
          state.fetch(:request_count) > @settings.fetch(:browser_max_requests)
        violation ||= "render_canceled" if canceled.call
        state[:violation] ||= violation
      end
      return request.abort if violation
      return request.abort unless request.method.to_s.in?(%w[GET HEAD])

      scheme = URI.parse(request.url).scheme.to_s.downcase
      if scheme.in?(%w[http https])
        @destination_policy.authorize!(url: request.url)
        request.continue
      elsif scheme.in?(INTERNAL_SCHEMES)
        request.continue
      else
        request.abort
      end
    rescue URI::InvalidURIError, Shared::Public::NetworkSafetyError
      state.fetch(:mutex).synchronize { state[:violation] ||= "unsafe_destination" }
      request.abort
    rescue StandardError
      request.abort
      raise
    end

    def summarize(traffic, state)
      responses = traffic.filter_map(&:response)
      status_counts = responses.group_by { |response| response.status.to_i.to_s }
        .transform_values(&:length).sort.to_h
      content_types = responses.filter_map(&:content_type).map { |value| value.to_s.first(128) }
        .tally.sort.to_h.first(25).to_h
      {
        "status_counts" => status_counts,
        "content_types" => content_types,
        "blocked_requests" => traffic.count(&:blocked?),
        "failed_requests" => traffic.count { |exchange| exchange.error.present? },
        "response_count" => responses.length,
        "request_count" => state.fetch(:request_count),
        "response_bytes" => state.fetch(:response_bytes)
      }.freeze
    end

    def network_state
      { mutex: Mutex.new, request_count: 0, response_bytes: 0, violation: nil }
    end

    def raise_network_violation!(state)
      reason = state.fetch(:mutex).synchronize { state[:violation] }
      return unless reason

      raise RenderError.new(reason_code: reason)
    end

    def raise_canceled!
      raise RenderError.new(reason_code: "render_canceled")
    end

    def append_message(target, value)
      return if target.length >= MAX_MESSAGES

      target << EvidenceSnippet.call(value, maximum_bytes: MAX_MESSAGE_BYTES)
    end

    def remaining(started)
      remaining = @settings.fetch(:browser_timeout) - (@monotonic_clock.call - started)
      raise RenderError.new(reason_code: "render_timeout", transient: true) unless remaining.positive?

      remaining
    end

    def ensure_render_worker!
      return if @settings.fetch(:process_role).to_s == "worker_render"

      raise Shared::Public::SecurityRejectedJobError, "browser execution requires worker_render"
    end
  end
end
