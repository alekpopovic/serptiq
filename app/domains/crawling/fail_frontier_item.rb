# frozen_string_literal: true

require "digest"

module Crawling
  class FailFrontierItem
    ACTIVE_SCAN_STATUSES = %w[queued running cancel_requested].freeze
    IDEMPOTENT_OUTCOMES = %w[retry rejected failed exhausted].freeze

    def initialize(clock: -> { Time.current }, progress: FrontierProgressRecorder.new)
      @clock = clock
      @progress = progress
    end

    def call(organization_id:, crawl_url_id:, worker_id:, lease_token:, failure_category:,
      retryable:, fetch_result_id: nil, http_status_code: nil)
      category = normalize_category(failure_category)
      result = normalize_result(fetch_result_id, http_status_code)
      item = nil
      outbox = nil
      CrawlUrl.transaction do
        item = CrawlUrl.lock.find_by!(organization_id: organization_id, id: crawl_url_id)
        return item if idempotent?(item, lease_token, category, result)

        now = @clock.call
        ensure_current_lease!(item, worker_id, lease_token, now)
        scan = Scan.lock.find_by!(organization_id: organization_id, id: item.scan_id)
        raise Conflict.new(reason_code: "frontier_scan_state_invalid") unless
          scan.status.in?(ACTIVE_SCAN_STATUSES)

        retrying = retryable == true && item.attempts < item.maximum_attempts &&
          scan.status != "cancel_requested"
        target = retrying ? "pending" : terminal_failure_state(retryable, scan)
        item.update!(failure_attributes(
          item: item,
          target: target,
          token: lease_token,
          category: category,
          now: now,
          result: result
        ))
        outbox = @progress.call(
          scan: scan,
          deltas: progress_deltas(target),
          operation_key: "failure:#{item.id}:#{item.last_lease_outcome}:#{item.last_lease_token_digest}",
          occurred_at: now
        )
      end
      ScanLifecycleRecord.enqueue(outbox)
      item
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "frontier_scope_unavailable"), cause: nil
    end

    private

    def normalize_category(value)
      category = value.to_s
      raise ArgumentError, "frontier failure category is invalid" unless
        CrawlUrl::FAILURE_PATTERN.match?(category)

      category
    end

    def normalize_result(result_id, status)
      id = result_id.nil? ? nil : Integer(result_id)
      code = status.nil? ? nil : Integer(status)
      raise ArgumentError, "frontier result is invalid" if id && !id.positive?
      raise ArgumentError, "HTTP status is invalid" unless code.nil? || code.between?(100, 599)
      raise ArgumentError, "HTTP status requires a result" if code && id.nil?

      { fetch_result_id: id, http_status_code: code }
    end

    def idempotent?(item, token, category, result)
      return false unless item.last_lease_token_matches?(token) &&
        item.last_lease_outcome.in?(IDEMPOTENT_OUTCOMES)

      matches = item.last_failure_category == category &&
        item.fetch_result_id == result.fetch(:fetch_result_id) &&
        item.http_status_code == result.fetch(:http_status_code)
      raise Conflict.new(reason_code: "frontier_completion_replay_conflict") unless matches

      true
    end

    def ensure_current_lease!(item, worker, token, now)
      valid = CrawlUrl::WORKER_PATTERN.match?(worker.to_s) && token.to_s.bytesize == 64 &&
        item.leased? && item.leased_by == worker.to_s && item.lease_expires_at > now &&
        item.lease_token_matches?(token)
      raise Conflict.new(reason_code: "frontier_lease_lost") unless valid
    end

    def terminal_failure_state(retryable, scan)
      return "rejected" if scan.status == "cancel_requested"

      retryable == true ? "exhausted" : "failed"
    end

    def failure_attributes(item:, target:, token:, category:, now:, result:)
      outcome = target == "pending" ? "retry" : target
      {
        state: target,
        leased_by: nil,
        lease_token_digest: nil,
        leased_at: nil,
        lease_expires_at: nil,
        next_attempt_at: target == "pending" ? retry_at(item, now) : nil,
        last_lease_token_digest: Digest::SHA256.hexdigest(token.to_s),
        last_lease_outcome: outcome,
        last_failure_category: category,
        completed_at: target == "pending" ? nil : now,
        **result
      }
    end

    def retry_at(item, now)
      base = Rails.application.config.x.searchops.fetch(:crawler_frontier_retry_base_delay)
      now + [ base * (2**(item.attempts - 1)), 3600 ].min.seconds
    end

    def progress_deltas(target)
      deltas = { urls_running_count: -1 }
      return deltas.merge(urls_queued_count: 1) if target == "pending"
      return deltas.merge(urls_processed_count: 1, urls_skipped_count: 1) if target == "rejected"

      deltas.merge(urls_processed_count: 1, urls_failed_count: 1)
    end
  end
end
