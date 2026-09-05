# frozen_string_literal: true

require "digest"

module Crawling
  class PersistStaticFetch
    def initialize(clock: -> { Time.current }, artifact_capture: nil,
      usage_starter: nil, usage_finisher: nil)
      @clock = clock
      @artifact_capture = artifact_capture || ->(**attributes) { Public.capture_artifact(**attributes) }
      @usage_starter = usage_starter || ->(**attributes) { Public.start_usage_operation(**attributes) }
      @usage_finisher = usage_finisher || ->(**attributes) { Public.finish_usage_operation(**attributes) }
    end

    def call(scan:, item:, lease:, result:)
      source = source_key(item, lease.attempts)
      existing = CrawlFetchResult.find_by(scan_id: scan.id, crawl_url_id: item.id,
        attempt_number: lease.attempts)
      return verify_and_snapshot(scan, item, existing, lease, result) if existing

      artifact = capture_artifact(scan, item, result, source)
      record = CrawlFetchResult.create!(
        **identity(scan),
        crawl_url_id: item.id,
        artifact_id: artifact&.artifact_id,
        attempt_number: lease.attempts,
        source_key_digest: Digest::SHA256.hexdigest(source),
        lease_token_digest: Digest::SHA256.hexdigest(lease.token),
        request_method: result.method,
        outcome: result.outcome,
        failure_category: result.failure_category,
        http_status_code: result.status,
        final_url: result.final_url,
        final_url_digest: Digest::SHA256.hexdigest(result.final_url),
        media_type: result.media_type,
        charset: result.charset,
        content_encoding: result.content_encoding,
        response_headers: result.response_headers,
        header_bytes: result.header_bytes,
        compressed_bytes: result.compressed_bytes,
        decoded_bytes: result.decoded_bytes,
        body_sha256: result.body_sha256,
        sniffed_kind: result.sniffed_kind,
        request_count: result.request_count,
        retry_count: result.retry_count,
        redirect_count: result.redirect_count,
        duration_ms: result.duration_ms,
        fetched_at: @clock.call
      )
      create_page_snapshot(scan, item, record) if html_snapshot?(record)
      record
    rescue ActiveRecord::RecordNotUnique
      existing = CrawlFetchResult.find_by!(scan_id: scan.id, crawl_url_id: item.id,
        attempt_number: lease.attempts)
      verify_and_snapshot(scan, item, existing, lease, result)
    ensure
      close_body(result.artifact)
    end

    private

    def capture_artifact(scan, item, result, source)
      return unless result.artifact

      operation_source = "#{source}:artifact"
      operation = @usage_starter.call(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        source_key: operation_source,
        operation_kind: "artifact",
        at: @clock.call,
        metadata: { "artifact_kind" => "response_body" }
      )
      reference = @artifact_capture.call(
        **identity(scan).except(:scan_id).merge(scan_id: scan.id),
        source_type: "crawl_fetch",
        source_id: "#{item.id}-#{item.attempts}",
        kind: "response_body",
        media_type: result.media_type || "application/octet-stream",
        filename: "response-#{item.id}-#{item.attempts}#{file_extension(result)}",
        retention_class: "raw_crawl",
        retention_expires_at: @clock.call + retention_days(scan).days,
        io: result.artifact
      )
      finish_artifact_operation(scan, operation_source, operation, "accepted")
      reference
    rescue StandardError
      finish_artifact_operation(scan, operation_source, operation, "failed") if operation
      raise
    end

    def finish_artifact_operation(scan, source, operation, outcome)
      @usage_finisher.call(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        source_key: source,
        outcome: outcome,
        occurred_at: operation.attempted_at,
        at: @clock.call
      )
    end

    def create_page_snapshot(scan, item, record)
      PageSnapshot.create_or_find_by!(scan_id: scan.id, crawl_url_id: item.id) do |snapshot|
        snapshot.assign_attributes(
          **identity(scan),
          crawl_fetch_result_id: record.id,
          artifact_id: record.artifact_id,
          state: "pending",
          extraction_attempts: 0,
          maximum_extraction_attempts: item.maximum_attempts,
          next_attempt_at: @clock.call
        )
      end.tap do |snapshot|
        expected = snapshot.crawl_fetch_result_id == record.id && snapshot.artifact_id == record.artifact_id
        raise Conflict.new(reason_code: "page_snapshot_source_conflict") unless expected
      end
    end

    def html_snapshot?(record)
      record.outcome == "succeeded" && record.sniffed_kind == "html" && record.artifact_id.present?
    end

    def verify_existing!(record, lease, result)
      matches = record.lease_token_digest == Digest::SHA256.hexdigest(lease.token) &&
        record.outcome == result.outcome && record.http_status_code == result.status &&
        record.body_sha256 == result.body_sha256 && record.final_url == result.final_url
      raise Conflict.new(reason_code: "crawl_fetch_replay_conflict") unless matches

      record
    end

    def verify_and_snapshot(scan, item, record, lease, result)
      verified = verify_existing!(record, lease, result)
      create_page_snapshot(scan, item, verified) if html_snapshot?(verified)
      verified
    end

    def source_key(item, attempt)
      "crawl-url:#{item.id}:attempt:#{attempt}"
    end

    def identity(scan)
      {
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id,
        scan_id: scan.id
      }
    end

    def retention_days(scan)
      Integer(scan.settings_snapshot.to_h.fetch("artifact_retention_days", 1)).clamp(1, 3650)
    end

    def file_extension(result)
      result.sniffed_kind == "html" ? ".html" : ".bin"
    end

    def close_body(body)
      body.close! if body.respond_to?(:close!)
    rescue StandardError
      nil
    end
  end
end
