# frozen_string_literal: true

module TestSupport
  module ScanHelpers
    def create_scan_for(result, project:, property:, environment: property.environments.sole,
      scan_type: "full", at: Time.current, **overrides)
      Crawling::CreateScan.new(clock: -> { at }).call(
        actor_membership: result.membership,
        project_id: project.id,
        property_id: property.id,
        environment_id: environment.id,
        scan_type: scan_type,
        settings_snapshot: { "max_urls" => 20, "robots_behavior" => "respect" },
        entitlement_snapshot: { "crawl.manual" => true, "crawl.max_urls_per_scan" => 500 },
        engine_version: "crawler-1.0.0",
        rule_set_version: "rules-1.0.0",
        **overrides
      )
    end

    def transition_scan(scan, command, at: Time.current, **attributes)
      Crawling::Public.transition_scan(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        command: command,
        clock: -> { at },
        **attributes
      )
    end

    def create_crawl_fetch_result_for(scan:, crawl_url:, lease_token:, at: Time.current,
      outcome: "succeeded", status: 200, body: "", artifact_id: nil)
      existing = Crawling::CrawlFetchResult.find_by(
        scan_id: scan.id,
        crawl_url_id: crawl_url.id,
        attempt_number: crawl_url.attempts
      )
      return existing if existing

      url = crawl_url.fetch_url
      failure_category = if outcome == "succeeded"
        nil
      elsif outcome == "http_error"
        "http_#{status}"
      else
        "test_failure"
      end
      Crawling::CrawlFetchResult.create!(
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id,
        scan_id: scan.id,
        crawl_url_id: crawl_url.id,
        artifact_id: artifact_id,
        attempt_number: crawl_url.attempts,
        source_key_digest: Digest::SHA256.hexdigest("test-fetch:#{crawl_url.id}:#{crawl_url.attempts}"),
        lease_token_digest: Digest::SHA256.hexdigest(lease_token),
        request_method: "GET",
        outcome: outcome,
        failure_category: failure_category,
        http_status_code: status,
        final_url: url,
        final_url_digest: Digest::SHA256.hexdigest(url),
        media_type: "text/html",
        content_encoding: "identity",
        response_headers: { "content-type" => "text/html" },
        body_sha256: Digest::SHA256.hexdigest(body),
        sniffed_kind: "html",
        request_count: 1,
        retry_count: 0,
        redirect_count: 0,
        duration_ms: 1,
        fetched_at: at
      )
    end

    def run_scan_to(scan, target_status, at: Time.current)
      commands = %w[admit queue start complete]
      target_index = %w[admitted queued running completed].index(target_status.to_s)
      raise ArgumentError, "unsupported scan target status" unless target_index

      commands.first(target_index + 1).each_with_index do |command, index|
        scan = transition_scan(scan, command, at: at + index.seconds)
      end
      scan
    end
  end
end
