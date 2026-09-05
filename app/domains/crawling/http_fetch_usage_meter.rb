# frozen_string_literal: true

module Crawling
  class HttpFetchUsageMeter
    Denied = Data.define(:reason_code)

    def initialize(starter: nil, finisher: nil, clock: -> { Time.current })
      @starter = starter || ->(**attributes) { Public.start_usage_operation(**attributes) }
      @finisher = finisher || ->(**attributes) { Public.finish_usage_operation(**attributes) }
      @clock = clock
    end

    def start(context:, sequence:)
      @starter.call(
        organization_id: context.organization_id,
        scan_id: context.scan_id,
        source_key: context.source_key(sequence),
        operation_kind: "http_fetch",
        at: @clock.call,
        metadata: { "request_sequence" => Integer(sequence) }
      )
    rescue Usage::Public::QuotaExceeded
      Denied.new("quota_exhausted")
    end

    def finish(context:, sequence:, operation:, outcome:)
      return operation if operation.is_a?(Denied)

      @finisher.call(
        organization_id: context.organization_id,
        scan_id: context.scan_id,
        source_key: context.source_key(sequence),
        outcome: outcome,
        occurred_at: operation.attempted_at,
        at: @clock.call
      )
    end
  end
end
