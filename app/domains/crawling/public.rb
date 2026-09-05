# frozen_string_literal: true

module Crawling
  module Public
    module_function

    def policy(**attributes)
      PolicyReader.new.call(**attributes)
    end

    def configure_policy(**attributes)
      WritePolicy.new.call(**attributes, change_kind: "configured")
    end

    def reset_policy(**attributes)
      WritePolicy.new.call(**attributes, change_kind: "reset")
    end

    def snapshot_for_scan(**attributes)
      SnapshotPolicy.new.call(**attributes)
    end

    def admission_request(**attributes)
      AdmissionRequest.new(**attributes)
    end

    def admit_scan(clock: -> { Time.current }, command: nil, **attributes)
      request = command || AdmissionRequest.new(**attributes.extract!(
        :idempotency_key, :source, :project_id, :property_id, :environment_id,
        :scan_type, :baseline_scan_id, :release_id
      ))
      AdmitScan.new(clock: clock).call(request: request, **attributes)
    end

    def dispatch_scan(clock: -> { Time.current }, **attributes)
      DispatchScan.new(clock: clock).call(**attributes)
    end

    def schedule_pending_dispatches
      SchedulePendingDispatches.new.call
    end

    def frontier_entry(**attributes)
      FrontierEntry.new(**attributes)
    end

    def normalize_url(**attributes)
      UrlNormalizer.new.call(**attributes)
    end

    def crawler_user_agent(**attributes)
      CrawlerIdentity.http_user_agent(**attributes)
    end

    def fetch_http(permit_context:, **attributes)
      HttpFetcher.new.call(**attributes, permit_context: permit_context)
    end

    def host_key(**attributes)
      HostKey.new(**attributes)
    end

    def fetch_permit_context(**attributes)
      FetchPermitContext.new(**attributes)
    end

    def http_fetch_usage_context(**attributes)
      HttpFetchUsageContext.new(**attributes)
    end

    def acquire_fetch_permit(clock: -> { Time.current }, **attributes)
      AcquireFetchPermit.new(clock: clock).call(**attributes)
    end

    def release_fetch_permit(clock: -> { Time.current }, **attributes)
      ReleaseFetchPermit.new(clock: clock).call(**attributes)
    end

    def recover_stale_fetch_permits(clock: -> { Time.current }, **attributes)
      RecoverStaleFetchPermits.new(clock: clock).call(**attributes)
    end

    def set_emergency_control(clock: -> { Time.current }, **attributes)
      SetEmergencyControl.new(clock: clock).call(**attributes)
    end

    def pressure_metrics(**attributes)
      PressureMetrics.new.call(**attributes)
    end

    def url_scope_policy(**attributes)
      UrlScopePolicy.new(**attributes)
    end

    def url_scope_for_scan(**attributes)
      ResolveUrlScopePolicy.new.call(**attributes)
    end

    def cache_robots_policy(**attributes)
      CacheRobotsPolicy.new.call(**attributes)
    end

    def evaluate_robots_policy(**attributes)
      EvaluateRobotsPolicy.new.call(**attributes)
    end

    def robots_sitemap_candidates(**attributes)
      ReadRobotsSitemaps.new.call(**attributes)
    end

    def discover_sitemaps(clock: -> { Time.current }, **attributes)
      DiscoverSitemaps.new(clock: clock).call(**attributes)
    end

    def discover_frontier(clock: -> { Time.current }, **attributes)
      DiscoverFrontier.new(clock: clock).call(**attributes)
    end

    def lease_frontier(clock: -> { Time.current }, **attributes)
      LeaseFrontier.new(clock: clock).call(**attributes)
    end

    def heartbeat_frontier_lease(clock: -> { Time.current }, **attributes)
      HeartbeatFrontierLease.new(clock: clock).call(**attributes)
    end

    def finish_frontier_item(clock: -> { Time.current }, **attributes)
      FinishFrontierItem.new(clock: clock).call(**attributes)
    end

    def fail_frontier_item(clock: -> { Time.current }, **attributes)
      FailFrontierItem.new(clock: clock).call(**attributes)
    end

    def recover_stale_frontier_leases(clock: -> { Time.current }, **attributes)
      RecoverStaleFrontierLeases.new(clock: clock).call(**attributes)
    end

    def frontier_progress(clock: -> { Time.current }, **attributes)
      FrontierProgressQuery.new(clock: clock).call(**attributes)
    end

    def transition_scan(clock: -> { Time.current }, **attributes)
      TransitionScan.new(clock: clock).call(**attributes)
    end

    def request_scan_cancellation(clock: -> { Time.current }, **attributes)
      RequestScanCancellation.new(clock: clock).call(**attributes)
    end

    def record_scan_progress(clock: -> { Time.current }, **attributes)
      RecordScanProgress.new(clock: clock).call(**attributes)
    end

    def start_usage_operation(clock: -> { Time.current }, **attributes)
      StartScanUsageOperation.new(clock: clock).call(**attributes)
    end

    def finish_usage_operation(clock: -> { Time.current }, **attributes)
      FinishScanUsageOperation.new(clock: clock).call(**attributes)
    end

    def finalize_scan_usage(clock: -> { Time.current }, **attributes)
      FinalizeScanUsage.new(clock: clock).call(**attributes)
    end

    def recover_terminal_scan_usage(clock: -> { Time.current })
      RecoverTerminalScanUsage.new(finalizer: FinalizeScanUsage.new(clock: clock)).call
    end

    def initialize_static_crawl(clock: -> { Time.current }, **attributes)
      InitializeStaticCrawl.new(clock: clock).call(**attributes)
    end

    def orchestrate_static_crawl(clock: -> { Time.current }, **attributes)
      OrchestrateStaticCrawl.new(clock: clock).call(**attributes)
    end

    def extract_static_page_links(clock: -> { Time.current }, **attributes)
      ExtractStaticPageLinks.new(clock: clock).call(**attributes)
    end

    def schedule_page_render(clock: -> { Time.current }, **attributes)
      SchedulePageRender.new(clock: clock).call(**attributes)
    end

    def render_page(clock: -> { Time.current }, **attributes)
      RenderPage.new(clock: clock).call(**attributes)
    end

    def render_metrics(clock: -> { Time.current }, **attributes)
      RenderMetrics.new(clock: clock).call(**attributes)
    end

    def link_graph(**attributes)
      LinkGraphQuery.new.call(**attributes)
    end

    def conclude_static_crawl(clock: -> { Time.current }, **attributes)
      ConcludeStaticCrawl.new(clock: clock).call(**attributes)
    end

    def recover_static_crawl_work(clock: -> { Time.current })
      RecoverStaticCrawlWork.new(clock: clock).call
    end

    def scan_page(**attributes)
      ScanDirectory.new.page(**attributes)
    end

    def scan_details(**attributes)
      ScanDirectory.new.find(**attributes)
    end

    def scan_cost_breakdown(**attributes)
      ScanCostQuery.new.call(**attributes)
    end

    def adjust_scan_usage(**attributes)
      AdjustScanUsage.new.call(**attributes)
    end

    def latest_scan_observation(**attributes)
      LatestScanObservation.new.call(**attributes)
    end

    def compile_glob(value)
      GlobPattern.new(value: value)
    end

    def delete_for_lifecycle!(clock: -> { Time.current }, **attributes)
      DeleteForLifecycle.new(clock: clock).call(**attributes)
    end

    def signed_artifact_url(**attributes)
      SignArtifact.new.call(**attributes)
    end

    def capture_artifact(store: nil, clock: -> { Time.current }, **attributes)
      CaptureArtifact.new(store: store || artifact_store, clock: clock).call(**attributes)
    end

    def expire_artifacts(clock: -> { Time.current }, **attributes)
      ExpireArtifacts.new(clock: clock).call(**attributes)
    end

    def delete_artifact(store: nil, clock: -> { Time.current }, **attributes)
      DeleteArtifact.new(store: store || artifact_store, clock: clock).call(**attributes)
    end

    def reconcile_artifacts(store: nil, clock: -> { Time.current }, **attributes)
      ReconcileArtifacts.new(store: store || artifact_store, clock: clock).call(**attributes)
    end

    def artifact_storage_metrics(**attributes)
      ArtifactStorageMetrics.new.call(**attributes)
    end

    def set_artifact_legal_hold(clock: -> { Time.current }, **attributes)
      SetArtifactLegalHold.new(clock: clock).call(**attributes)
    end

    def artifact_store
      ArtifactStoreFactory.build
    end
  end
end
