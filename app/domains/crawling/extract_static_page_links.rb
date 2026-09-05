# frozen_string_literal: true

require "addressable/uri"
require "nokogiri"
require "securerandom"

module Crawling
  class ExtractStaticPageLinks
    PARSER_VERSION = "link-discovery-1.0"
    MAX_LINKS = 5_000
    MAX_HREF_BYTES = 8_192
    Claim = Data.define(:snapshot, :token)
    Canceled = Class.new(StandardError)

    def initialize(clock: -> { Time.current }, store: ArtifactStoreFactory.build,
      discoverer: nil)
      @clock = clock
      @store = store
      @discoverer = discoverer || ->(**attributes) { Public.discover_frontier(**attributes) }
    end

    def call(organization_id:, scan_id:, page_snapshot_id:, worker_id:)
      snapshot = exact_snapshot!(organization_id, scan_id, page_snapshot_id)
      claim = claim(snapshot, worker_id)
      return snapshot.reload unless claim

      body = download(claim.snapshot)
      raise Canceled if canceled?(claim.snapshot)

      count = discover_links(claim.snapshot, body)
      complete(claim, count)
    rescue Canceled
      skip(claim, "scan_canceled") if claim
    rescue AccessDenied
      raise
    rescue StandardError => error
      fail_claim(claim, error) if claim
      Shared::Public.report_observability_failure(error, event_name: "crawler.page_extraction")
      claim&.snapshot&.reload
    end

    private

    def exact_snapshot!(organization_id, scan_id, page_snapshot_id)
      PageSnapshot.find_by!(
        organization_id: organization_id,
        scan_id: scan_id,
        id: page_snapshot_id
      )
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "page_snapshot_scope_unavailable"), cause: nil
    end

    def claim(snapshot, worker_id)
      worker = worker_id.to_s
      raise ArgumentError, "page extraction worker is invalid" unless CrawlUrl::WORKER_PATTERN.match?(worker)

      token = nil
      PageSnapshot.transaction do
        scan = Scan.lock.find_by!(organization_id: snapshot.organization_id, id: snapshot.scan_id)
        snapshot = PageSnapshot.lock.find_by!(
          organization_id: snapshot.organization_id,
          scan_id: snapshot.scan_id,
          id: snapshot.id
        )
        next if snapshot.terminal?
        next if snapshot.processing? && snapshot.extraction_lease_expires_at > @clock.call

        if scan.status != "running"
          terminalize!(snapshot, "skipped", scan.status == "cancel_requested" ? "scan_canceled" : "scan_unavailable")
          next
        end
        if snapshot.extraction_attempts >= snapshot.maximum_extraction_attempts
          terminalize!(snapshot, "failed", "extraction_exhausted")
          next
        end

        token = SecureRandom.hex(32)
        now = @clock.call
        snapshot.update!(
          state: "processing",
          extraction_attempts: snapshot.extraction_attempts + 1,
          extraction_worker_id: worker,
          extraction_token_digest: Digest::SHA256.hexdigest(token),
          extraction_started_at: now,
          extraction_lease_expires_at: now + extraction_lease_duration.seconds,
          next_attempt_at: nil,
          last_failure_category: nil
        )
      end
      Claim.new(snapshot, token) if token
    end

    def download(snapshot)
      artifact = Artifact.includes(:blob).find_by!(
        organization_id: snapshot.organization_id,
        project_id: snapshot.project_id,
        property_id: snapshot.property_id,
        environment_id: snapshot.environment_id,
        scan_id: snapshot.scan_id,
        id: snapshot.artifact_id
      )
      raise ArtifactStore::MissingObject.new(reason_code: "artifact_object_missing") unless artifact.downloadable?

      limit = Rails.application.config.x.searchops.fetch(:crawler_max_decompressed_bytes)
      body = +"".b
      @store.download(key: artifact.blob.object_key) do |chunk|
        body << chunk
        raise Invalid.new(reason_code: "extraction_body_too_large") if body.bytesize > limit
      end
      body.freeze
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "page_snapshot_artifact_unavailable"), cause: nil
    end

    def discover_links(snapshot, body)
      document = Nokogiri::HTML5.parse(body, max_errors: 0)
      scope = Public.url_scope_for_scan(
        organization_id: snapshot.organization_id,
        scan_id: snapshot.scan_id
      )
      settings = snapshot.scan.settings_snapshot.to_h.stringify_keys
      entries = []
      seen = {}
      document.css("a[href]").first(MAX_LINKS).each_with_index do |node, index|
        raise Canceled if (index % 100).zero? && canceled?(snapshot)

        href = node["href"].to_s
        next if href.blank? || href.bytesize > MAX_HREF_BYTES

        url = resolve_url(snapshot.fetch_result.final_url, href)
        decision = scope.evaluate(url: url, depth: snapshot.crawl_url.depth + 1)
        next unless decision.allowed?
        next if seen[decision.normalized_url.identity_digest]

        seen[decision.normalized_url.identity_digest] = true
        entries << Public.frontier_entry(
          url: url,
          depth: snapshot.crawl_url.depth + 1,
          priority: 0,
          discovery_source: "link",
          discovered_from_id: snapshot.crawl_url_id,
          query_handling: settings.fetch("query_handling", "all"),
          query_parameter_allowlist: settings.fetch("query_parameter_allowlist", []),
          query_parameter_denylist: settings.fetch("query_parameter_denylist", [])
        )
      rescue Addressable::URI::InvalidURIError, ArgumentError
        next
      end

      entries.each_slice(DiscoverFrontier::MAXIMUM_BATCH_SIZE).sum do |batch|
        @discoverer.call(
          organization_id: snapshot.organization_id,
          scan_id: snapshot.scan_id,
          entries: batch,
          clock: @clock
        ).inserted_count
      end
    end

    def resolve_url(base, href)
      Addressable::URI.join(base, href).to_s
    end

    def complete(claim, count)
      claim.snapshot.with_lock do
        verify_claim!(claim)
        terminalize!(
          claim.snapshot,
          "completed",
          nil,
          discovered_links_count: count,
          discovery_parser_version: PARSER_VERSION
        )
      end
      claim.snapshot
    end

    def skip(claim, category)
      claim.snapshot.with_lock do
        return claim.snapshot unless claim.snapshot.processing? &&
          claim.snapshot.extraction_token_matches?(claim.token)

        terminalize!(claim.snapshot, "skipped", category)
      end
      claim.snapshot
    end

    def fail_claim(claim, error)
      claim.snapshot.with_lock do
        return unless claim.snapshot.processing? && claim.snapshot.extraction_token_matches?(claim.token)

        scan = claim.snapshot.scan.reload
        category = failure_category(error)
        if scan.status == "running" &&
            claim.snapshot.extraction_attempts < claim.snapshot.maximum_extraction_attempts
          now = @clock.call
          claim.snapshot.update!(
            state: "pending",
            extraction_worker_id: nil,
            extraction_token_digest: nil,
            extraction_started_at: nil,
            extraction_lease_expires_at: nil,
            next_attempt_at: now + retry_delay(claim.snapshot).seconds,
            last_failure_category: category
          )
        else
          target = scan.status == "running" ? "failed" : "skipped"
          terminalize!(claim.snapshot, target, category)
        end
      end
    end

    def terminalize!(snapshot, state, category, discovered_links_count: 0,
      discovery_parser_version: nil)
      snapshot.update!(
        state: state,
        extraction_worker_id: nil,
        extraction_token_digest: nil,
        extraction_started_at: nil,
        extraction_lease_expires_at: nil,
        next_attempt_at: nil,
        last_failure_category: category,
        discovered_links_count: discovered_links_count,
        discovery_parser_version: discovery_parser_version,
        finished_at: @clock.call
      )
    end

    def verify_claim!(claim)
      valid = claim.snapshot.processing? && claim.snapshot.extraction_token_matches?(claim.token)
      raise Conflict.new(reason_code: "page_extraction_lease_lost") unless valid
    end

    def canceled?(snapshot)
      Scan.where(organization_id: snapshot.organization_id, id: snapshot.scan_id,
        status: %w[cancel_requested canceled]).exists?
    end

    def failure_category(error)
      value = error.respond_to?(:reason_code) ? error.reason_code.to_s : "extraction_failed"
      CrawlUrl::FAILURE_PATTERN.match?(value) ? value : "extraction_failed"
    end

    def retry_delay(snapshot)
      base = Rails.application.config.x.searchops.fetch(:crawler_frontier_retry_base_delay)
      [ base * (2**(snapshot.extraction_attempts - 1)), 3600 ].min
    end

    def extraction_lease_duration
      Rails.application.config.x.searchops.fetch(:crawler_frontier_lease_duration)
    end
  end
end
