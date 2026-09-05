# frozen_string_literal: true

module Crawling
  class HttpFetchRecorder
    def initialize(emitter: ->(name, **attributes) { Shared::Public.emit_structured_event(name, **attributes) })
      raise ArgumentError, "HTTP fetch event emitter is invalid" unless emitter.respond_to?(:call)

      @emitter = emitter
    end

    def call(result)
      @emitter.call(
        "crawler.http_fetch",
        severity: result.successful? ? :info : :warn,
        outcome: event_outcome(result),
        operation: result.method.downcase,
        reason_code: result.failure_category,
        http_status: result.status,
        duration_ms: result.duration_ms,
        retry_count: result.retry_count
      )
    rescue StandardError => error
      Shared::Public.report_observability_failure(error, event_name: "crawler.http_fetch")
    end

    private

    def event_outcome(result)
      return "succeeded" if result.successful?
      return "retrying" if result.outcome == "throttled"
      return "denied" if result.outcome.in?(%w[rejected canceled])

      "failed"
    end
  end
end
