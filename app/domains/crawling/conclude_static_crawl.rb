# frozen_string_literal: true

module Crawling
  class ConcludeStaticCrawl
    STOP_REASONS = %w[quota_exhausted scan_deadline_exceeded].freeze

    def initialize(clock: -> { Time.current }, halter: nil)
      @clock = clock
      @halter = halter || HaltStaticCrawl.new(clock: clock)
    end

    def call(organization_id:, scan_id:, stop_reason: nil)
      scan = Scan.find_by!(organization_id: organization_id, id: scan_id)
      return scan if scan.terminal?

      if scan.status == "cancel_requested"
        @halter.call(organization_id: organization_id, scan_id: scan_id, reason_code: "scan_canceled")
        return transition(scan.reload, "acknowledge_cancel")
      end
      if STOP_REASONS.include?(stop_reason.to_s)
        @halter.call(organization_id: organization_id, scan_id: scan_id, reason_code: stop_reason)
        scan.reload
        return transition(scan, "acknowledge_cancel") if scan.status == "cancel_requested"
        return scan if scan.terminal?

        return transition(scan, "complete_partially")
      end
      return scan unless scan.status == "running"

      result = nil
      Scan.transaction do
        scan = Scan.lock.find_by!(organization_id: organization_id, id: scan_id)
        next unless scan.status == "running"
        next if durable_work_remains?(scan)

        command = partial?(scan) ? "complete_partially" : "complete"
        result = transition(scan, command)
      end
      result || scan.reload
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "static_crawl_scope_unavailable"), cause: nil
    end

    private

    def durable_work_remains?(scan)
      CrawlUrl.where(scan_id: scan.id, state: %w[pending leased]).exists? ||
        PageSnapshot.where(scan_id: scan.id, state: %w[pending processing]).exists? ||
        StaticCrawlExecution.where(scan_id: scan.id, state: %w[pending initializing]).exists?
    end

    def partial?(scan)
      scan.urls_failed_count.positive? || scan.urls_skipped_count.positive? ||
        PageSnapshot.where(scan_id: scan.id, state: %w[failed skipped]).exists? ||
        SitemapDiscovery.where(scan_id: scan.id, status: %w[failed partially_completed]).exists? ||
        StaticCrawlExecution.where(scan_id: scan.id, state: "failed").exists?
    end

    def transition(scan, command)
      result = Public.transition_scan(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        command: command,
        clock: @clock
      )
      finish_execution(result)
      result
    end

    def finish_execution(scan)
      execution = StaticCrawlExecution.find_by(scan_id: scan.id)
      return unless execution

      execution.with_lock do
        execution.update!(
          state: scan.status,
          initialization_worker_id: nil,
          initialization_token_digest: nil,
          initialization_started_at: nil,
          initialization_lease_expires_at: nil,
          last_live_update_at: nil,
          finished_at: @clock.call
        )
      end
    end
  end
end
