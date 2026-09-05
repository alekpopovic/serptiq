# frozen_string_literal: true

module Crawling
  class RecoverStaticCrawlWork
    BATCH_SIZE = 100

    def initialize(clock: -> { Time.current }, crawl_enqueuer: nil, extraction_enqueuer: nil)
      @clock = clock
      @crawl_enqueuer = crawl_enqueuer || lambda { |organization_id, scan_id|
        StaticCrawlOrchestratorJob.perform_later(
          organization_id: organization_id, scan_id: scan_id
        )
      }
      @extraction_enqueuer = extraction_enqueuer || lambda { |organization_id, scan_id, snapshot_id|
        StaticPageExtractionJob.perform_later(
          organization_id: organization_id,
          scan_id: scan_id,
          page_snapshot_id: snapshot_id
        )
      }
    end

    def call
      recover_initializations
      recover_extractions
      enqueue_crawls
      enqueue_extractions
      true
    end

    private

    def recover_initializations
      candidates = StaticCrawlExecution.where(state: "initializing")
        .where(initialization_lease_expires_at: ..@clock.call)
        .order(:initialization_lease_expires_at, :id).limit(BATCH_SIZE)
        .pluck(:id, :organization_id, :scan_id)
      candidates.each { |candidate| recover_initialization(candidate) }
    end

    def recover_initialization(candidate)
      execution_id, organization_id, scan_id = candidate
      Scan.transaction do
        scan = Scan.lock.find_by!(organization_id: organization_id, id: scan_id)
        execution = StaticCrawlExecution.lock.find(execution_id)
        next unless execution.initializing? && execution.initialization_lease_expires_at <= @clock.call

        exhausted = execution.initialization_attempts >= execution.maximum_initialization_attempts
        execution.update!(
          state: exhausted ? "failed" : "pending",
          initialization_worker_id: nil,
          initialization_token_digest: nil,
          initialization_started_at: nil,
          initialization_lease_expires_at: nil,
          last_failure_category: "initialization_lease_expired",
          finished_at: exhausted ? @clock.call : nil
        )
        fail_scan(scan, "initialization_exhausted") if exhausted
      end
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def recover_extractions
      PageSnapshot.transaction do
        PageSnapshot.where(state: "processing")
          .where(extraction_lease_expires_at: ..@clock.call)
          .order(:extraction_lease_expires_at, :id).limit(BATCH_SIZE)
          .lock("FOR UPDATE SKIP LOCKED").each do |snapshot|
            scan = snapshot.scan
            retryable = scan.status == "running" &&
              snapshot.extraction_attempts < snapshot.maximum_extraction_attempts
            snapshot.update!(
              state: retryable ? "pending" : (scan.status == "running" ? "failed" : "skipped"),
              extraction_worker_id: nil,
              extraction_token_digest: nil,
              extraction_started_at: nil,
              extraction_lease_expires_at: nil,
              next_attempt_at: retryable ? @clock.call : nil,
              last_failure_category: "extraction_lease_expired",
              finished_at: retryable ? nil : @clock.call
            )
          end
      end
    end

    def enqueue_crawls
      Scan.where(status: %w[queued running cancel_requested]).order(:queued_at, :id)
        .limit(BATCH_SIZE).pluck(:organization_id, :id).each do |organization_id, scan_id|
          @crawl_enqueuer.call(organization_id, scan_id)
        end
    end

    def enqueue_extractions
      PageSnapshot.where(state: "pending", next_attempt_at: ..@clock.call)
        .order(:next_attempt_at, :id).limit(BATCH_SIZE)
        .pluck(:organization_id, :scan_id, :id).each do |organization_id, scan_id, snapshot_id|
          @extraction_enqueuer.call(organization_id, scan_id, snapshot_id)
        end
    end

    def fail_scan(scan, category)
      return if scan.terminal?

      Public.transition_scan(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        command: "fail",
        failure_category: category,
        clock: @clock
      )
    end
  end
end
