# frozen_string_literal: true

module Crawling
  class RecoverStaleFrontierLeases
    BATCH_SIZE = 500
    ACTIVE_SCAN_STATUSES = %w[queued running cancel_requested].freeze

    def initialize(clock: -> { Time.current }, progress: FrontierProgressRecorder.new)
      @clock = clock
      @progress = progress
    end

    def call(limit: BATCH_SIZE)
      batch_size = Integer(limit)
      raise ArgumentError, "stale lease batch is invalid" unless batch_size.between?(1, BATCH_SIZE)

      now = @clock.call
      recovered = []
      outboxes = []
      CrawlUrl.transaction do
        items = CrawlUrl.stale_at(now).order(:lease_expires_at, :id)
          .lock("FOR UPDATE SKIP LOCKED").limit(batch_size).to_a
        scans = Scan.lock.where(id: items.map(&:scan_id).uniq).order(:id).index_by(&:id)
        deltas = Hash.new { |hash, key| hash[key] = Hash.new(0) }
        items.each do |item|
          scan = scans.fetch(item.scan_id)
          target = recovery_target(item, scan)
          item.update!(recovery_attributes(item, target, now))
          apply_delta!(deltas[item.scan_id], target) if scan.status.in?(ACTIVE_SCAN_STATUSES)
          recovered << item
        end
        deltas.sort.each do |scan_id, counters|
          next if counters.values.all?(&:zero?)

          outboxes << @progress.call(
            scan: scans.fetch(scan_id),
            deltas: counters,
            operation_key: recovery_operation_key(recovered.select { |item| item.scan_id == scan_id }),
            occurred_at: now
          )
        end
      end
      outboxes.each { |outbox| ScanLifecycleRecord.enqueue(outbox) }
      recovered.freeze
    end

    private

    def recovery_target(item, scan)
      return "rejected" if scan.status == "cancel_requested" || scan.status.in?(Scan::TERMINAL_STATUSES)
      return "exhausted" if item.attempts >= item.maximum_attempts

      "pending"
    end

    def recovery_attributes(item, target, now)
      outcome = target == "pending" ? "stale_recovered" : target
      {
        state: target,
        leased_by: nil,
        lease_token_digest: nil,
        leased_at: nil,
        lease_expires_at: nil,
        next_attempt_at: target == "pending" ? retry_at(item, now) : nil,
        last_lease_token_digest: item.lease_token_digest,
        last_lease_outcome: outcome,
        last_failure_category: target == "rejected" ? "scan_unavailable" : "lease_expired",
        completed_at: target == "pending" ? nil : now
      }
    end

    def retry_at(item, now)
      base = Rails.application.config.x.searchops.fetch(:crawler_frontier_retry_base_delay)
      now + [ base * (2**(item.attempts - 1)), 3600 ].min.seconds
    end

    def apply_delta!(delta, target)
      delta[:urls_running_count] -= 1
      if target == "pending"
        delta[:urls_queued_count] += 1
      elsif target == "rejected"
        delta[:urls_processed_count] += 1
        delta[:urls_skipped_count] += 1
      else
        delta[:urls_processed_count] += 1
        delta[:urls_failed_count] += 1
      end
    end

    def recovery_operation_key(items)
      evidence = items.sort_by(&:id).map do |item|
        "#{item.id}:#{item.attempts}:#{item.last_lease_outcome}"
      end.join(":")
      "recover:#{Digest::SHA256.hexdigest(evidence)}"
    end
  end
end
