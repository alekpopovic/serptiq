# frozen_string_literal: true

require "securerandom"

module Crawling
  class InitializeStaticCrawl
    Claim = Data.define(:execution, :token)

    def initialize(clock: -> { Time.current }, robots_builder: nil, sitemap_builder: nil,
      frontier_discoverer: nil, progress: FrontierProgressRecorder.new)
      @clock = clock
      @robots_builder = robots_builder || lambda { |scan|
        CacheRobotsPolicy.new(retriever: MeteredRobotsRetriever.new(scan: scan, clock: @clock))
      }
      @sitemap_builder = sitemap_builder || lambda { |scan|
        DiscoverSitemaps.new(retriever: MeteredSitemapRetriever.new(scan: scan, clock: @clock), clock: @clock)
      }
      @frontier_discoverer = frontier_discoverer || ->(**attributes) { Public.discover_frontier(**attributes) }
      @progress = progress
    end

    def call(organization_id:, scan_id:, worker_id:)
      scan = start_scan(organization_id, scan_id)
      return StaticCrawlExecution.find_by(scan_id: scan.id) if
        scan.terminal? || scan.status == "cancel_requested"
      raise Conflict.new(reason_code: "scan_not_running") unless scan.status == "running"

      claim = claim_initialization(scan, worker_id)
      return execution_for(scan) unless claim

      initialize_claim(scan, claim)
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied.new(reason_code: "static_crawl_scope_unavailable"), cause: nil
    rescue StandardError => error
      fail_claim(claim, error) if claim
      raise
    end

    private

    def start_scan(organization_id, scan_id)
      scan = Scan.find_by!(organization_id: organization_id, id: scan_id)
      scan = Public.transition_scan(
        organization_id: organization_id, scan_id: scan_id,
        command: "start", clock: @clock
      ) if scan.status == "queued"
      scan
    end

    def execution_for(scan)
      StaticCrawlExecution.find_or_create_by!(scan_id: scan.id) do |execution|
        execution.assign_attributes(identity(scan))
      end
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    def claim_initialization(scan, worker_id)
      worker = worker_id.to_s
      raise ArgumentError, "static crawl worker is invalid" unless CrawlUrl::WORKER_PATTERN.match?(worker)

      execution = nil
      token = nil
      Scan.transaction do
        scan = Scan.lock.find_by!(organization_id: scan.organization_id, id: scan.id)
        execution = execution_for(scan)
        execution.lock!
        return if execution.ready? || execution.terminal?
        return if execution.initializing? && execution.initialization_lease_expires_at > @clock.call

        if execution.initialization_attempts >= execution.maximum_initialization_attempts
          exhaust_initialization!(execution)
          fail_scan(scan, "initialization_exhausted")
          return
        end
        token = SecureRandom.hex(32)
        now = @clock.call
        execution.update!(
          state: "initializing",
          initialization_attempts: execution.initialization_attempts + 1,
          initialization_worker_id: worker,
          initialization_token_digest: Digest::SHA256.hexdigest(token),
          initialization_started_at: now,
          initialization_lease_expires_at: now + initialization_lease_duration.seconds,
          last_failure_category: nil
        )
      end
      Claim.new(execution, token) if token
    end

    def initialize_claim(scan, claim)
      ensure_running!(scan)
      robots = @robots_builder.call(scan).call(organization_id: scan.organization_id, scan_id: scan.id)
      return complete_claim(claim, stop_reason: "quota_exhausted") if
        robots.respond_to?(:error_code) && robots.error_code == "quota_exhausted"

      ensure_running!(scan.reload)
      @sitemap_builder.call(scan).call(organization_id: scan.organization_id, scan_id: scan.id)
      return complete_claim(claim, stop_reason: "quota_exhausted") if
        SitemapFile.where(scan_id: scan.id, error_code: "quota_exhausted").exists?

      ensure_running!(scan.reload)
      seed_start_urls(scan.reload)
      complete_claim(claim)
    end

    def seed_start_urls(scan)
      settings = scan.settings_snapshot.to_h.stringify_keys
      environment = Properties::Public.environment_reference(
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id
      ) || raise(ActiveRecord::RecordNotFound)
      urls = Array(settings["start_urls"]).presence ||
        [ "#{environment.origin.origin}/" ]
      scope = Public.url_scope_for_scan(organization_id: scan.organization_id, scan_id: scan.id)
      entries = urls.filter_map do |url|
        decision = scope.evaluate(url: url, depth: 0)
        next unless decision.allowed?

        Public.frontier_entry(
          url: url,
          depth: 0,
          priority: 100,
          discovery_source: "seed",
          query_handling: settings.fetch("query_handling", "all"),
          query_parameter_allowlist: settings.fetch("query_parameter_allowlist", []),
          query_parameter_denylist: settings.fetch("query_parameter_denylist", [])
        )
      end
      @frontier_discoverer.call(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        entries: entries,
        clock: @clock
      ) if entries.any?
      record_target(scan)
    end

    def record_target(scan)
      outbox = nil
      Scan.transaction do
        locked = Scan.lock.find_by!(organization_id: scan.organization_id, id: scan.id)
        next if locked.targets_count.positive?

        outbox = @progress.call(
          scan: locked,
          deltas: { targets_count: 1 },
          operation_key: "static-target:#{locked.environment_id}",
          occurred_at: @clock.call
        )
      end
      ScanLifecycleRecord.enqueue(outbox) if outbox
    end

    def complete_claim(claim, stop_reason: nil)
      claim.execution.with_lock do
        return claim.execution if claim.execution.ready?
        verify_claim!(claim)
        now = @clock.call
        claim.execution.update!(
          state: "ready",
          initialization_worker_id: nil,
          initialization_token_digest: nil,
          initialization_started_at: nil,
          initialization_lease_expires_at: nil,
          initialized_at: now,
          last_failure_category: stop_reason
        )
      end
      claim.execution
    end

    def fail_claim(claim, error)
      Scan.transaction do
        scan = Scan.lock.find_by!(
          organization_id: claim.execution.organization_id,
          id: claim.execution.scan_id
        )
        execution = StaticCrawlExecution.lock.find(claim.execution.id)
        return unless execution.initializing? && execution.initialization_token_matches?(claim.token)

        exhausted = execution.initialization_attempts >= execution.maximum_initialization_attempts
        now = @clock.call
        execution.update!(
          state: exhausted ? "failed" : "pending",
          initialization_worker_id: nil,
          initialization_token_digest: nil,
          initialization_started_at: nil,
          initialization_lease_expires_at: nil,
          last_failure_category: failure_category(error),
          finished_at: exhausted ? now : nil
        )
        fail_scan(scan, "initialization_exhausted") if exhausted
      end
    rescue StandardError => recovery_error
      Shared::Public.report_observability_failure(
        recovery_error, event_name: "crawler.static_initialization_recovery"
      )
    end

    def exhaust_initialization!(execution)
      execution.update!(
        state: "failed",
        last_failure_category: "initialization_exhausted",
        finished_at: @clock.call
      )
    end

    def fail_scan(scan, category)
      Public.transition_scan(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        command: "fail",
        failure_category: category,
        clock: @clock
      ) unless scan.reload.terminal?
    end

    def verify_claim!(claim)
      valid = claim.execution.initializing? && claim.execution.initialization_token_matches?(claim.token)
      raise Conflict.new(reason_code: "static_crawl_initialization_lease_lost") unless valid
    end

    def ensure_running!(scan)
      return if scan.status == "running"

      raise Conflict.new(reason_code: scan.status == "cancel_requested" ? "scan_canceled" : "scan_not_running")
    end

    def failure_category(error)
      value = error.respond_to?(:reason_code) ? error.reason_code.to_s : "initialization_failed"
      CrawlUrl::FAILURE_PATTERN.match?(value) ? value : "initialization_failed"
    end

    def initialization_lease_duration
      Rails.application.config.x.searchops.fetch(:crawler_frontier_lease_duration)
    end

    def identity(scan)
      {
        organization_id: scan.organization_id,
        project_id: scan.project_id,
        property_id: scan.property_id,
        environment_id: scan.environment_id
      }
    end
  end
end
