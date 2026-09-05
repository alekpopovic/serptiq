# frozen_string_literal: true

require "digest"

module Crawling
  class MeteredSitemapRetriever
    def initialize(scan:, delegate: RetrieveSitemap.new, usage_meter: nil, clock: -> { Time.current })
      @scan = scan
      @delegate = delegate
      @usage_meter = usage_meter || HttpFetchUsageMeter.new(clock: clock)
    end

    def call(origin:, url:)
      context = HttpFetchUsageContext.new(
        organization_id: @scan.organization_id,
        scan_id: @scan.id,
        source_key_prefix: "scan:#{@scan.id}:sitemap:#{Digest::SHA256.hexdigest(url.to_s)}"
      )
      @delegate.call(
        origin: origin,
        url: url,
        request_observer: MeteredHttpRequestObserver.new(context: context, meter: @usage_meter)
      )
    end
  end
end
