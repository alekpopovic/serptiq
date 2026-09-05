# frozen_string_literal: true

module Crawling
  class MeteredRobotsRetriever
    def initialize(scan:, delegate: RetrieveRobots.new, usage_meter: nil, clock: -> { Time.current })
      @scan = scan
      @delegate = delegate
      @usage_meter = usage_meter || HttpFetchUsageMeter.new(clock: clock)
    end

    def call(origin:)
      context = HttpFetchUsageContext.new(
        organization_id: @scan.organization_id,
        scan_id: @scan.id,
        source_key_prefix: "scan:#{@scan.id}:robots"
      )
      @delegate.call(
        origin: origin,
        request_observer: MeteredHttpRequestObserver.new(context: context, meter: @usage_meter)
      )
    end
  end
end
