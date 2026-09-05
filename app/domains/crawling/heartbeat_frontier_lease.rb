# frozen_string_literal: true

module Crawling
  class HeartbeatFrontierLease
    def initialize(clock: -> { Time.current })
      @clock = clock
    end

    def call(organization_id:, crawl_url_id:, worker_id:, lease_token:, lease_duration: nil)
      worker = worker_id.to_s
      duration = bounded_duration(lease_duration)
      now = @clock.call
      item = CrawlUrl.lock.find_by!(organization_id: organization_id, id: crawl_url_id)
      ensure_current_lease!(item, worker, lease_token, now)
      item.update!(lease_expires_at: now + duration.seconds)
      item
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "frontier_scope_unavailable"), cause: nil
    end

    private

    def bounded_duration(value)
      maximum = Rails.application.config.x.searchops.fetch(:crawler_frontier_lease_duration)
      duration = Float(value || maximum)
      raise ArgumentError, "frontier lease duration is invalid" unless duration.between?(15, maximum)

      duration
    end

    def ensure_current_lease!(item, worker, token, now)
      valid = CrawlUrl::WORKER_PATTERN.match?(worker) && token.to_s.bytesize == 64 &&
        item.leased? && item.leased_by == worker && item.lease_expires_at > now &&
        item.lease_token_matches?(token)
      raise Conflict.new(reason_code: "frontier_lease_lost") unless valid
    end
  end
end
