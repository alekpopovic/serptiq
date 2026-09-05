# frozen_string_literal: true

module Crawling
  class FetchStaticPage
    TRANSIENT_STATUSES = HttpFetcher::TRANSIENT_STATUSES
    TRANSIENT_FAILURES = (HttpFetcher::TRANSIENT_ERRORS + %w[
      throttled global_rate organization_rate scan_rate host_rate host_backoff
      global_concurrency organization_concurrency scan_concurrency host_concurrency
      frontier_permit_active
    ]).freeze

    def initialize(clock: -> { Time.current }, fetcher: HttpFetcher.new,
      persister: nil, extraction_enqueuer: nil)
      @clock = clock
      @fetcher = fetcher
      @persister = persister || PersistStaticFetch.new(clock: clock)
      @extraction_enqueuer = extraction_enqueuer || lambda { |snapshot|
        StaticPageExtractionJob.perform_later(
          organization_id: snapshot.organization_id,
          scan_id: snapshot.scan_id,
          page_snapshot_id: snapshot.id
        )
      }
    end

    def call(lease:)
      scan, item = exact_context!(lease)
      return reject_canceled(lease) if scan.status == "cancel_requested"

      if (existing = existing_result(item, lease))
        complete_frontier(lease, existing)
        enqueue_snapshot(existing)
        return existing
      end

      robots = Public.evaluate_robots_policy(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        url: item.fetch_url
      )
      return reject_by_robots(lease, robots) unless robots.crawl_permitted?

      result = @fetcher.call(
        url: item.fetch_url,
        approved_redirect_origins: [ scope_origin(scan) ],
        sink_factory: -> { TemporaryBodySink.new },
        cancellation: -> { cancellation_requested?(scan) },
        permit_context: Public.fetch_permit_context(
          organization_id: scan.organization_id,
          scan_id: scan.id,
          crawl_url_id: item.id,
          worker_id: lease.worker_id,
          frontier_lease_token: lease.token
        ),
        usage_context: Public.http_fetch_usage_context(
          organization_id: scan.organization_id,
          scan_id: scan.id,
          source_key_prefix: "crawl-url:#{item.id}:attempt:#{lease.attempts}"
        )
      )
      persisted = @persister.call(scan: scan, item: item, lease: lease, result: result)
      complete_frontier(lease, persisted)
      enqueue_snapshot(persisted)
      persisted
    rescue AccessDenied
      raise
    rescue Conflict => error
      raise unless error.reason_code.in?(%w[frontier_lease_lost fetch_permit_scope_unavailable])

      nil
    rescue StandardError => error
      contain_worker_failure(lease, error)
    end

    private

    def exact_context!(lease)
      scan = Scan.find_by!(
        organization_id: lease.organization_id,
        project_id: lease.project_id,
        property_id: lease.property_id,
        environment_id: lease.environment_id,
        id: lease.scan_id
      )
      item = CrawlUrl.find_by!(
        organization_id: lease.organization_id,
        project_id: lease.project_id,
        property_id: lease.property_id,
        environment_id: lease.environment_id,
        scan_id: lease.scan_id,
        id: lease.id
      )
      valid = item.leased? && item.leased_by == lease.worker_id && item.lease_token_matches?(lease.token)
      raise Conflict.new(reason_code: "frontier_lease_lost") unless valid

      [ scan, item ]
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "static_crawl_scope_unavailable"), cause: nil
    end

    def existing_result(item, lease)
      CrawlFetchResult.find_by(
        scan_id: item.scan_id,
        crawl_url_id: item.id,
        attempt_number: lease.attempts
      )&.tap do |result|
        raise Conflict.new(reason_code: "crawl_fetch_replay_conflict") unless
          result.lease_token_digest == Digest::SHA256.hexdigest(lease.token)
      end
    end

    def complete_frontier(lease, result)
      if result.outcome == "succeeded"
        Public.finish_frontier_item(**completion_identity(lease), outcome: "succeeded",
          fetch_result_id: result.id, http_status_code: result.http_status_code)
      elsif result.outcome.in?(%w[rejected canceled])
        Public.finish_frontier_item(**completion_identity(lease), outcome: "rejected",
          fetch_result_id: result.id, http_status_code: result.http_status_code,
          failure_category: result.failure_category || "request_rejected")
      else
        Public.fail_frontier_item(
          **completion_identity(lease),
          failure_category: result.failure_category || "http_fetch_failed",
          retryable: retryable?(result),
          fetch_result_id: result.id,
          http_status_code: result.http_status_code
        )
      end
    end

    def reject_canceled(lease)
      Public.fail_frontier_item(
        **completion_identity(lease), failure_category: "scan_canceled", retryable: false
      )
    end

    def reject_by_robots(lease, decision)
      category = decision.denied? ? "robots_denied" : "robots_unknown"
      Public.finish_frontier_item(
        **completion_identity(lease), outcome: "rejected", failure_category: category
      )
    end

    def retryable?(result)
      TRANSIENT_STATUSES.include?(result.http_status_code) ||
        TRANSIENT_FAILURES.include?(result.failure_category) || result.outcome == "throttled"
    end

    def enqueue_snapshot(result)
      snapshot = result.page_snapshot
      return unless snapshot&.pending?

      @extraction_enqueuer.call(snapshot)
    rescue StandardError => error
      Shared::Public.report_observability_failure(
        error, event_name: "crawler.page_extraction_enqueue"
      )
    end

    def contain_worker_failure(lease, error)
      category = safe_failure_category(error)
      Shared::Public.report_observability_failure(error, event_name: "crawler.static_page")
      Public.fail_frontier_item(
        **completion_identity(lease), failure_category: category, retryable: true
      )
      nil
    rescue Conflict => frontier_error
      raise unless frontier_error.reason_code == "frontier_lease_lost"

      nil
    end

    def safe_failure_category(error)
      value = error.respond_to?(:reason_code) ? error.reason_code.to_s : "worker_error"
      CrawlUrl::FAILURE_PATTERN.match?(value) ? value : "worker_error"
    end

    def cancellation_requested?(scan)
      Scan.where(organization_id: scan.organization_id, id: scan.id,
        status: %w[cancel_requested canceled]).exists?
    end

    def scope_origin(scan)
      Properties::Public.environment_reference(
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id
      )&.origin&.origin || raise(AccessDenied.new(reason_code: "static_crawl_scope_unavailable"))
    end

    def completion_identity(lease)
      {
        organization_id: lease.organization_id,
        crawl_url_id: lease.id,
        worker_id: lease.worker_id,
        lease_token: lease.token
      }
    end
  end
end
