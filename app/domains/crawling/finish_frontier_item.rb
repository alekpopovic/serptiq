# frozen_string_literal: true

require "digest"

module Crawling
  class FinishFrontierItem
    ACTIVE_SCAN_STATUSES = %w[queued running cancel_requested].freeze
    TERMINAL_OUTCOMES = %w[succeeded rejected].freeze

    def initialize(clock: -> { Time.current }, progress: FrontierProgressRecorder.new)
      @clock = clock
      @progress = progress
    end

    def call(organization_id:, crawl_url_id:, worker_id:, lease_token:, outcome:,
      fetch_result_id: nil, http_status_code: nil, failure_category: nil)
      target = outcome.to_s
      raise ArgumentError, "frontier outcome is invalid" unless TERMINAL_OUTCOMES.include?(target)
      result = normalize_result(target, fetch_result_id, http_status_code, failure_category)
      item = nil
      outbox = nil
      CrawlUrl.transaction do
        item = CrawlUrl.lock.find_by!(organization_id: organization_id, id: crawl_url_id)
        return item if idempotent?(item, lease_token, target, result)

        now = @clock.call
        ensure_current_lease!(item, worker_id, lease_token, now)
        scan = Scan.lock.find_by!(organization_id: organization_id, id: item.scan_id)
        raise Conflict.new(reason_code: "frontier_scan_state_invalid") unless
          scan.status.in?(ACTIVE_SCAN_STATUSES)

        item.update!(terminal_attributes(
          target: target,
          token: lease_token,
          now: now,
          **result
        ))
        outbox = @progress.call(
          scan: scan,
          deltas: progress_deltas(target),
          operation_key: "finish:#{item.id}:#{target}:#{item.last_lease_token_digest}",
          occurred_at: now
        )
      end
      ScanLifecycleRecord.enqueue(outbox)
      item
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "frontier_scope_unavailable"), cause: nil
    end

    private

    def normalize_result(target, result_id, status, failure_category)
      id = result_id.nil? ? nil : Integer(result_id)
      code = status.nil? ? nil : Integer(status)
      if target == "succeeded"
        raise ArgumentError, "successful frontier result is required" unless id&.positive?
      end
      raise ArgumentError, "HTTP status requires a fetch result" if code && id.nil?
      raise ArgumentError, "HTTP status is invalid" unless code.nil? || code.between?(100, 599)
      category = failure_category&.to_s
      raise ArgumentError, "failure category is invalid" unless
        category.nil? || CrawlUrl::FAILURE_PATTERN.match?(category)

      { fetch_result_id: id, http_status_code: code, failure_category: category }
    end

    def idempotent?(item, token, target, result)
      return false unless item.state == target && item.last_lease_outcome == target &&
        item.last_lease_token_matches?(token)

      matches = item.fetch_result_id == result.fetch(:fetch_result_id) &&
        item.http_status_code == result.fetch(:http_status_code) &&
        item.last_failure_category == result.fetch(:failure_category)
      raise Conflict.new(reason_code: "frontier_completion_replay_conflict") unless matches

      true
    end

    def ensure_current_lease!(item, worker, token, now)
      valid = CrawlUrl::WORKER_PATTERN.match?(worker.to_s) && token.to_s.bytesize == 64 &&
        item.leased? && item.leased_by == worker.to_s && item.lease_expires_at > now &&
        item.lease_token_matches?(token)
      raise Conflict.new(reason_code: "frontier_lease_lost") unless valid
    end

    def terminal_attributes(target:, token:, now:, fetch_result_id:, http_status_code:, failure_category:)
      {
        state: target,
        leased_by: nil,
        lease_token_digest: nil,
        leased_at: nil,
        lease_expires_at: nil,
        next_attempt_at: nil,
        last_lease_token_digest: Digest::SHA256.hexdigest(token.to_s),
        last_lease_outcome: target,
        last_failure_category: failure_category,
        fetch_result_id: fetch_result_id,
        http_status_code: http_status_code,
        completed_at: now
      }
    end

    def progress_deltas(target)
      deltas = { urls_running_count: -1, urls_processed_count: 1 }
      counter = target == "succeeded" ? :urls_succeeded_count : :urls_skipped_count
      deltas.merge(counter => 1)
    end
  end
end
