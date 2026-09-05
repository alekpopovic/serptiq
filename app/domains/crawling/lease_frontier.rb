# frozen_string_literal: true

require "digest"

module Crawling
  class LeaseFrontier
    def initialize(clock: -> { Time.current }, query: FrontierLeaseQuery.new,
      progress: FrontierProgressRecorder.new)
      @clock = clock
      @query = query
      @progress = progress
    end

    def call(worker_id:, limit: nil, lease_duration: nil)
      worker = worker_id.to_s
      settings = Rails.application.config.x.searchops
      maximum_batch = settings.fetch(:crawler_frontier_lease_batch_size)
      batch_size = Integer(limit || maximum_batch)
      maximum_duration = settings.fetch(:crawler_frontier_lease_duration)
      duration = Float(lease_duration || maximum_duration)
      unless CrawlUrl::WORKER_PATTERN.match?(worker) && batch_size.between?(1, maximum_batch) &&
          duration.between?(15, maximum_duration)
        raise ArgumentError, "frontier lease request is invalid"
      end

      now = @clock.call
      leases = []
      outboxes = []
      CrawlUrl.transaction do
        leases = @query.lease(
          worker_id: worker,
          limit: batch_size,
          leased_at: now,
          lease_expires_at: now + duration.seconds
        )
        leases.group_by(&:scan_id).sort.each do |scan_id, scan_leases|
          scan = Scan.lock.find_by!(organization_id: scan_leases.first.organization_id, id: scan_id)
          raise Conflict.new(reason_code: "frontier_scan_state_invalid") unless
            scan.status.in?(FrontierLeaseQuery::ACTIVE_SCAN_STATUSES)

          count = scan_leases.length
          outboxes << @progress.call(
            scan: scan,
            deltas: { urls_queued_count: -count, urls_running_count: count },
            operation_key: lease_operation_key(scan_leases),
            occurred_at: now
          )
        end
      end
      outboxes.each { |outbox| ScanLifecycleRecord.enqueue(outbox) }
      leases.freeze
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "frontier_scope_unavailable"), cause: nil
    end

    private

    def lease_operation_key(leases)
      digests = leases.map { |lease| Digest::SHA256.hexdigest(lease.token) }.sort.join(":")
      "lease:#{Digest::SHA256.hexdigest(digests)}"
    end
  end
end
