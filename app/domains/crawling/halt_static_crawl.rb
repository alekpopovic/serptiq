# frozen_string_literal: true

module Crawling
  class HaltStaticCrawl
    def initialize(clock: -> { Time.current }, progress: FrontierProgressRecorder.new)
      @clock = clock
      @progress = progress
    end

    def call(organization_id:, scan_id:, reason_code:)
      category = reason_code.to_s
      raise ArgumentError, "static crawl halt reason is invalid" unless
        CrawlUrl::FAILURE_PATTERN.match?(category)

      outbox = nil
      Scan.transaction do
        items = CrawlUrl.where(
          organization_id: organization_id,
          scan_id: scan_id,
          state: %w[pending leased]
        ).lock.order(:id).to_a
        scan = Scan.lock.find_by!(organization_id: organization_id, id: scan_id)
        queued = items.count(&:pending?)
        running = items.count(&:leased?)
        now = @clock.call
        expire_permits(items, now)
        items.each { |item| reject_item(item, category, now) }
        skip_snapshots(scan, category, now)
        if items.any?
          outbox = @progress.call(
            scan: scan,
            deltas: {
              urls_queued_count: -queued,
              urls_running_count: -running,
              urls_processed_count: items.length,
              urls_skipped_count: items.length
            },
            operation_key: "halt:#{category}:#{Digest::SHA256.hexdigest(items.map(&:id).join(':'))}",
            occurred_at: now
          )
        end
      end
      ScanLifecycleRecord.enqueue(outbox) if outbox
      true
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "static_crawl_scope_unavailable"), cause: nil
    end

    private

    def expire_permits(items, now)
      ids = items.map(&:id)
      return if ids.empty?

      FetchPermit.where(crawl_url_id: ids, state: "active").update_all(
        state: "expired",
        released_at: now,
        release_outcome: "expired",
        failure_category: "permit_expired",
        updated_at: now
      )
    end

    def reject_item(item, category, now)
      digest = item.lease_token_digest || Digest::SHA256.hexdigest(
        "static-crawl-halt:#{item.scan_id}:#{item.id}:#{category}"
      )
      item.update!(
        state: "rejected",
        leased_by: nil,
        lease_token_digest: nil,
        leased_at: nil,
        lease_expires_at: nil,
        next_attempt_at: nil,
        last_lease_token_digest: digest,
        last_lease_outcome: "rejected",
        last_failure_category: category,
        completed_at: now
      )
    end

    def skip_snapshots(scan, category, now)
      PageSnapshot.where(scan_id: scan.id, state: %w[pending processing]).update_all(
        state: "skipped",
        extraction_worker_id: nil,
        extraction_token_digest: nil,
        extraction_started_at: nil,
        extraction_lease_expires_at: nil,
        next_attempt_at: nil,
        last_failure_category: category,
        finished_at: now,
        updated_at: now
      )
    end
  end
end
