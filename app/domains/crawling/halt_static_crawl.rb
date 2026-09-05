# frozen_string_literal: true

module Crawling
  class HaltStaticCrawl
    def initialize(clock: -> { Time.current }, progress: FrontierProgressRecorder.new,
      usage_finisher: nil)
      @clock = clock
      @progress = progress
      @usage_finisher = usage_finisher || ->(**attributes) { Public.finish_usage_operation(**attributes) }
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
        cancel_renders(scan, category, now)
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

    def cancel_renders(scan, category, now)
      PageRender.where(scan_id: scan.id, state: %w[pending processing]).lock.order(:id).each do |render|
        finish_render_usage(render, now) if render.processing?
        render.update!(
          state: category == "scan_canceled" ? "canceled" : "skipped",
          worker_id: nil,
          lease_token_digest: nil,
          started_at: nil,
          lease_expires_at: nil,
          next_attempt_at: nil,
          failure_category: category,
          finished_at: now
        )
      end
    end

    def finish_render_usage(render, now)
      source_key = RenderPage.usage_source_key(render)
      operation = ScanUsageOperation.find_by(
        organization_id: render.organization_id,
        scan_id: render.scan_id,
        source_key_digest: Digest::SHA256.hexdigest(source_key),
        state: "reserved"
      )
      return unless operation

      @usage_finisher.call(
        organization_id: render.organization_id,
        scan_id: render.scan_id,
        source_key: source_key,
        outcome: "canceled",
        occurred_at: now,
        at: now,
        metadata: { "page_render_id" => render.id, "attempt" => render.attempts }
      )
    end
  end
end
