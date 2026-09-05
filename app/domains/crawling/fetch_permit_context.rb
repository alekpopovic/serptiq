# frozen_string_literal: true

module Crawling
  FetchPermitContext = Data.define(
    :organization_id, :scan_id, :crawl_url_id, :worker_id, :frontier_lease_token
  ) do
    def initialize(**attributes)
      %i[organization_id scan_id worker_id frontier_lease_token].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      attributes[:crawl_url_id] = Integer(attributes.fetch(:crawl_url_id))
      valid = Shared::Public.application_uuid?(attributes[:organization_id]) &&
        Shared::Public.application_uuid?(attributes[:scan_id]) && attributes[:crawl_url_id].positive? &&
        CrawlUrl::WORKER_PATTERN.match?(attributes[:worker_id]) &&
        attributes[:frontier_lease_token].bytesize == 64
      raise ArgumentError, "fetch permit context is invalid" unless valid

      super(**attributes)
      freeze
    end
  end
end
