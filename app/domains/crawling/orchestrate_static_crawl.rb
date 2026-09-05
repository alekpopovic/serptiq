# frozen_string_literal: true

module Crawling
  class OrchestrateStaticCrawl
    WORK_BATCH_SIZE = 1

    def initialize(clock: -> { Time.current }, initializer: nil, leaser: nil,
      fetcher: nil, concluder: nil, live_update: nil, enqueuer: nil)
      @clock = clock
      @initializer = initializer || InitializeStaticCrawl.new(clock: clock)
      @leaser = leaser || LeaseFrontier.new(clock: clock)
      @fetcher = fetcher || FetchStaticPage.new(clock: clock)
      @concluder = concluder || ConcludeStaticCrawl.new(clock: clock)
      @live_update = live_update || ScanLiveUpdate.new(clock: clock)
      @enqueuer = enqueuer || lambda { |organization_id, scan_id|
        StaticCrawlOrchestratorJob.perform_later(
          organization_id: organization_id,
          scan_id: scan_id
        )
      }
    end

    def call(organization_id:, scan_id:, worker_id:)
      scan = exact_scan!(organization_id, scan_id)
      return scan if scan.terminal?

      if scan.status == "cancel_requested"
        return conclude_and_publish(scan)
      end

      execution = @initializer.call(
        organization_id: organization_id,
        scan_id: scan_id,
        worker_id: worker_id
      )
      scan = exact_scan!(organization_id, scan_id)
      return conclude_and_publish(scan) unless execution&.ready? && scan.status == "running"

      stop_reason = execution.last_failure_category if
        execution.last_failure_category.in?(ConcludeStaticCrawl::STOP_REASONS)
      unless stop_reason
        @leaser.call(
          worker_id: worker_id,
          limit: WORK_BATCH_SIZE,
          organization_id: organization_id,
          scan_id: scan_id
        ).each do |lease|
          result = @fetcher.call(lease: lease)
          stop_reason ||= result&.failure_category if
            result&.failure_category.in?(ConcludeStaticCrawl::STOP_REASONS)
          break if stop_reason || cancellation_requested?(organization_id, scan_id)
        end
      end

      scan = @concluder.call(
        organization_id: organization_id,
        scan_id: scan_id,
        stop_reason: stop_reason
      )
      publish(scan)
      enqueue_continuation(scan)
      scan
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "static_crawl_scope_unavailable"), cause: nil
    end

    private

    def exact_scan!(organization_id, scan_id)
      Scan.find_by!(organization_id: organization_id, id: scan_id)
    end

    def conclude_and_publish(scan)
      result = @concluder.call(organization_id: scan.organization_id, scan_id: scan.id)
      publish(result)
      result
    end

    def publish(scan)
      @live_update.call(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        force: scan.terminal?
      )
    end

    def enqueue_continuation(scan)
      return if scan.terminal? || scan.status != "running"
      return unless CrawlUrl.where(
        scan_id: scan.id,
        state: "pending",
        next_attempt_at: ..@clock.call
      ).exists?

      @enqueuer.call(scan.organization_id, scan.id)
    rescue StandardError => error
      Shared::Public.report_observability_failure(
        error, event_name: "crawler.static_continuation_enqueue"
      )
    end

    def cancellation_requested?(organization_id, scan_id)
      Scan.where(organization_id: organization_id, id: scan_id,
        status: %w[cancel_requested canceled]).exists?
    end
  end
end
