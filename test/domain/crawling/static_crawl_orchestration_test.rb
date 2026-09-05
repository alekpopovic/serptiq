# frozen_string_literal: true

require "test_helper"

class CrawlingStaticCrawlOrchestrationTest < ActiveSupport::TestCase
  Callable = Struct.new(:result) do
    def call(**)
      result
    end
  end

  Resolver = Struct.new(:calls) do
    def resolve(host:)
      calls << host
      [ "93.184.216.34" ]
    end
  end

  class LocalSiteTransport
    attr_reader :calls

    def initialize(pages)
      @pages = pages
      @calls = []
    end

    def request(destination:, sink:, **)
      url = destination.target.url
      @calls << url
      body = @pages.fetch(url)
      sink.write(body)
      Shared::NetworkSafety::BoundedTransportResponse.new(
        status: 200,
        headers: { "content-type" => "text/html; charset=utf-8" },
        header_bytes: 48,
        compressed_bytes: body.bytesize,
        decoded_bytes: body.bytesize,
        body_sha256: Digest::SHA256.hexdigest(body),
        sniffed_kind: "html",
        timings: { connect_ms: 1, tls_ms: 1, header_ms: 1, body_ms: 1, total_ms: 4 }
      )
    end
  end

  class NoopUsageMeter
    Operation = Data.define(:attempted_at)

    def start(**)
      Operation.new(Time.current)
    end

    def finish(**)
      true
    end
  end

  setup do
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "static-crawl-owner")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "static-crawl-project")
    @property = create_property_for(
      @owner,
      project: @project,
      configuration: { origin: "https://example.com" }
    )
    @scan = create_scan_for(
      @owner,
      project: @project,
      property: @property,
      at: @now - 1.minute,
      settings_snapshot: {
        "start_urls" => [ "https://example.com/" ],
        "max_urls" => 2,
        "max_depth" => 2,
        "query_handling" => "all",
        "query_parameter_allowlist" => [],
        "query_parameter_denylist" => [],
        "artifact_retention_days" => 2,
        "robots_behavior" => "respect"
      }
    )
    @scan = run_scan_to(@scan, "queued", at: @now - 30.seconds)
    create_robots_snapshot
    @store = TestSupport::FakeArtifactStore.new
  end

  test "crawls a local scripted site through fetch artifacts link discovery limits and terminal accounting" do
    pages = {
      "https://example.com/" => <<~HTML,
        <!doctype html><a href="/about">About</a><a href="/ignored">Ignored by cap</a>
      HTML
      "https://example.com/about" => "<!doctype html><p>Done</p>"
    }
    transport = LocalSiteTransport.new(pages)
    resolver = Resolver.new([])
    http_fetcher = Crawling::HttpFetcher.new(
      destination_policy: Shared::NetworkSafety::DestinationPolicy.new(resolver: resolver),
      transport: transport,
      limits: transport_limits,
      safe_retries: 0,
      retry_waiter: ->(*) { },
      usage_meter: NoopUsageMeter.new,
      pressure_acquirer: ->(**) { pressure_decision },
      pressure_releaser: ->(**) { true }
    )
    snapshots = []
    page_fetcher = Crawling::FetchStaticPage.new(
      clock: -> { @now },
      fetcher: http_fetcher,
      persister: Crawling::PersistStaticFetch.new(
        clock: -> { @now },
        artifact_capture: lambda { |**attributes|
          Crawling::CaptureArtifact.new(store: @store, clock: -> { @now }).call(**attributes)
        }
      ),
      extraction_enqueuer: ->(snapshot) { snapshots << snapshot.id }
    )
    initializer = Crawling::InitializeStaticCrawl.new(
      clock: -> { @now },
      robots_builder: ->(_scan) { Callable.new(@scan.robots_snapshots.sole) },
      sitemap_builder: ->(_scan) { Callable.new(nil) }
    )
    orchestrator = Crawling::OrchestrateStaticCrawl.new(
      clock: -> { @now },
      initializer: initializer,
      fetcher: page_fetcher,
      live_update: Callable.new(true),
      enqueuer: ->(*) { true }
    )
    extractor = Crawling::ExtractStaticPageLinks.new(clock: -> { @now }, store: @store)

    orchestrator.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      worker_id: "crawl-local-1"
    )
    root_snapshot = Crawling::PageSnapshot.find(snapshots.shift)
    extractor.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      page_snapshot_id: root_snapshot.id,
      worker_id: "extract-local-1"
    )

    orchestrator.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      worker_id: "crawl-local-2"
    )
    about_snapshot = Crawling::PageSnapshot.find(snapshots.shift)
    extractor.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      page_snapshot_id: about_snapshot.id,
      worker_id: "extract-local-2"
    )
    completed = Crawling::ConcludeStaticCrawl.new(clock: -> { @now }).call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id
    )

    assert_equal "completed", completed.status
    assert_equal 2, completed.urls_discovered_count
    assert_equal 2, completed.urls_processed_count
    assert_equal 2, completed.urls_succeeded_count
    assert_equal %w[https://example.com/ https://example.com/about], transport.calls
    assert_equal [ "example.com", "example.com" ], resolver.calls
    assert_equal 2, Crawling::CrawlFetchResult.where(scan_id: @scan.id).count
    assert_equal 2, Crawling::PageSnapshot.where(scan_id: @scan.id, state: "completed").count
    assert_equal 2, Crawling::PageFact.where(scan_id: @scan.id).count
    assert_equal 2, root_snapshot.crawl_links.count
    assert_equal "not_admitted",
      root_snapshot.crawl_links.find_by!(destination_url: "https://example.com/ignored").discovery_status
    assert_equal 2, Crawling::Artifact.where(scan_id: @scan.id).count
    assert_equal %w[https://example.com/ https://example.com/about],
      Crawling::CrawlUrl.where(scan_id: @scan.id).order(:id).pluck(:normalized_url)
    assert_no_difference [ "Crawling::CrawlUrl.count", "Crawling::PageSnapshot.count" ] do
      extractor.call(
        organization_id: @scan.organization_id,
        scan_id: @scan.id,
        page_snapshot_id: root_snapshot.id,
        worker_id: "extract-local-replay"
      )
    end
  end

  test "cancellation drains durable work and a foreign job scope cannot inspect the scan" do
    initializer = Crawling::InitializeStaticCrawl.new(
      clock: -> { @now },
      robots_builder: ->(_scan) { Callable.new(@scan.robots_snapshots.sole) },
      sitemap_builder: ->(_scan) { Callable.new(nil) }
    )
    initializer.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      worker_id: "crawl-cancel-init"
    )
    Crawling::Public.request_scan_cancellation(
      actor_membership: @owner.membership,
      project_id: @project.id,
      scan_id: @scan.id,
      clock: -> { @now }
    )

    canceled = Crawling::ConcludeStaticCrawl.new(clock: -> { @now }).call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id
    )

    assert_equal "canceled", canceled.status
    assert_equal 0, canceled.urls_queued_count
    assert_equal 0, canceled.urls_running_count
    assert Crawling::CrawlUrl.where(scan_id: @scan.id).all?(&:rejected?)

    foreign = create_organization_for(slug: "static-crawl-foreign")
    assert_raises(Crawling::AccessDenied) do
      Crawling::OrchestrateStaticCrawl.new.call(
        organization_id: foreign.organization.id,
        scan_id: @scan.id,
        worker_id: "crawl-foreign"
      )
    end
  end

  test "credit and deadline stops terminalize remaining frontier as a partial observation" do
    initializer = Crawling::InitializeStaticCrawl.new(
      clock: -> { @now },
      robots_builder: ->(_scan) { Callable.new(@scan.robots_snapshots.sole) },
      sitemap_builder: ->(_scan) { Callable.new(nil) }
    )
    initializer.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      worker_id: "crawl-limit-init"
    )
    Crawling::Public.discover_frontier(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      entries: [
        Crawling::Public.frontier_entry(
          url: "https://example.com/about",
          depth: 1,
          discovery_source: "link"
        )
      ],
      clock: -> { @now }
    )

    stopped = Crawling::ConcludeStaticCrawl.new(clock: -> { @now }).call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      stop_reason: "quota_exhausted"
    )

    assert_equal "partially_completed", stopped.status
    assert_equal 2, stopped.urls_processed_count
    assert_equal 2, stopped.urls_skipped_count
    assert_equal 0, stopped.urls_queued_count
    assert Crawling::CrawlUrl.where(scan_id: @scan.id).all?(&:rejected?)
    assert @scan.quota_reservation.nil?, "legacy test scan has no quota hold to finalize"
  end

  test "initialization quota denial stops before sitemap and page work" do
    quota_observation = Struct.new(:error_code).new("quota_exhausted")
    sitemap_calls = 0
    page_calls = 0
    initializer = Crawling::InitializeStaticCrawl.new(
      clock: -> { @now },
      robots_builder: ->(_scan) { Callable.new(quota_observation) },
      sitemap_builder: lambda { |_scan|
        sitemap_calls += 1
        Callable.new(nil)
      }
    )
    orchestrator = Crawling::OrchestrateStaticCrawl.new(
      clock: -> { @now },
      initializer: initializer,
      fetcher: lambda { |**|
        page_calls += 1
      },
      live_update: Callable.new(true),
      enqueuer: ->(*) { true }
    )

    result = orchestrator.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      worker_id: "crawl-quota-init"
    )

    assert_equal "partially_completed", result.status
    assert_equal "partially_completed", @scan.static_crawl_execution.reload.state
    assert_equal "quota_exhausted", @scan.static_crawl_execution.last_failure_category
    assert_equal 0, sitemap_calls
    assert_equal 0, page_calls
    assert_equal 0, Crawling::CrawlUrl.where(scan_id: @scan.id).count
  end

  test "poison fetch failures return the lease to its durable retry budget" do
    initializer = Crawling::InitializeStaticCrawl.new(
      clock: -> { @now },
      robots_builder: ->(_scan) { Callable.new(@scan.robots_snapshots.sole) },
      sitemap_builder: ->(_scan) { Callable.new(nil) }
    )
    initializer.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      worker_id: "crawl-poison-init"
    )
    lease = Crawling::LeaseFrontier.new(clock: -> { @now }).call(
      worker_id: "crawl-poison",
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      limit: 1
    ).sole
    raising = Callable.new(nil)
    def raising.call(**)
      raise "synthetic poison response"
    end

    result = Crawling::FetchStaticPage.new(clock: -> { @now }, fetcher: raising).call(lease: lease)

    assert_nil result
    item = Crawling::CrawlUrl.find(lease.id)
    assert_equal "pending", item.state
    assert_equal "retry", item.last_lease_outcome
    assert_equal "worker_error", item.last_failure_category
    assert_equal 1, @scan.reload.urls_queued_count
    assert_equal 0, @scan.urls_running_count
  end

  test "recovery requeues a crashed initialization lease without duplicating tenant work" do
    token = SecureRandom.hex(32)
    execution = Crawling::StaticCrawlExecution.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      state: "initializing",
      initialization_attempts: 1,
      maximum_initialization_attempts: 3,
      initialization_worker_id: "crashed-worker",
      initialization_token_digest: Digest::SHA256.hexdigest(token),
      initialization_started_at: @now - 3.minutes,
      initialization_lease_expires_at: @now - 1.minute
    )
    crawl_jobs = []
    service = Crawling::RecoverStaticCrawlWork.new(
      clock: -> { @now },
      crawl_enqueuer: ->(organization_id, scan_id) { crawl_jobs << [ organization_id, scan_id ] },
      extraction_enqueuer: ->(*) { raise "no extraction expected" }
    )

    assert service.call
    assert_equal "pending", execution.reload.state
    assert_equal "initialization_lease_expired", execution.last_failure_category
    assert_equal [ [ @scan.organization_id, @scan.id ] ], crawl_jobs

    service.call
    assert_equal 2, crawl_jobs.length
    assert_equal 1, Crawling::StaticCrawlExecution.where(scan_id: @scan.id).count
  end

  test "initialization lease exhaustion fails the scan durably" do
    execution = Crawling::StaticCrawlExecution.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      state: "initializing",
      initialization_attempts: 3,
      maximum_initialization_attempts: 3,
      initialization_worker_id: "crashed-final-worker",
      initialization_token_digest: Digest::SHA256.hexdigest(SecureRandom.hex(32)),
      initialization_started_at: @now - 3.minutes,
      initialization_lease_expires_at: @now - 1.minute
    )
    service = Crawling::RecoverStaticCrawlWork.new(
      clock: -> { @now },
      crawl_enqueuer: ->(*) { true },
      extraction_enqueuer: ->(*) { true }
    )

    assert service.call
    assert_equal "failed", execution.reload.state
    assert_equal "initialization_lease_expired", execution.last_failure_category
    assert_equal "failed", @scan.reload.status
    assert_equal "initialization_exhausted", @scan.failure_category
  end

  test "terminal live refresh is emitted once across duplicate jobs" do
    @scan = Crawling::Public.request_scan_cancellation(
      actor_membership: @owner.membership,
      project_id: @project.id,
      scan_id: @scan.id,
      clock: -> { @now }
    )
    execution = Crawling::StaticCrawlExecution.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      state: "canceled",
      finished_at: @now
    )
    broadcasts = []
    updater = Crawling::ScanLiveUpdate.new(
      clock: -> { @now },
      broadcaster: ->(organization_id, scan_id) { broadcasts << [ organization_id, scan_id ] }
    )

    assert updater.call(organization_id: @scan.organization_id, scan_id: @scan.id, force: true)
    refute updater.call(organization_id: @scan.organization_id, scan_id: @scan.id, force: true)
    assert_equal [ [ @scan.organization_id, @scan.id ] ], broadcasts
    assert_equal @now, execution.reload.last_live_update_at
  end

  test "fetch replay repairs a missing HTML snapshot after a crash" do
    initialize_frontier("crawl-snapshot-crash")
    lease = Crawling::LeaseFrontier.new(clock: -> { @now }).call(
      worker_id: "crawl-snapshot-replay",
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      limit: 1
    ).sole
    item = Crawling::CrawlUrl.find(lease.id)
    body = "<!doctype html><a href='/recovered'>Recovered</a>"
    artifact = Crawling::CaptureArtifact.new(store: @store, clock: -> { @now }).call(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      source_type: "crawl_fetch",
      source_id: SecureRandom.uuid,
      kind: "response_body",
      media_type: "text/html",
      filename: "response.html",
      retention_class: "raw_crawl",
      retention_expires_at: @now + 1.day,
      io: StringIO.new(body)
    )
    existing = create_crawl_fetch_result_for(
      scan: @scan,
      crawl_url: item,
      lease_token: lease.token,
      at: @now,
      body: body,
      artifact_id: artifact.artifact_id
    )
    transport = LocalSiteTransport.new(item.fetch_url => body)
    fetched = Crawling::HttpFetcher.new(
      destination_policy: Shared::NetworkSafety::DestinationPolicy.new(resolver: Resolver.new([])),
      transport: transport,
      limits: transport_limits,
      safe_retries: 0,
      retry_waiter: ->(*) { },
      usage_meter: NoopUsageMeter.new,
      pressure_acquirer: ->(**) { pressure_decision },
      pressure_releaser: ->(**) { true }
    ).call(url: item.fetch_url, sink_factory: -> { Crawling::TemporaryBodySink.new })
    persister = Crawling::PersistStaticFetch.new(clock: -> { @now })

    assert_difference("Crawling::PageSnapshot.count", 1) do
      assert_equal existing.id, persister.call(
        scan: @scan, item: item, lease: lease, result: fetched
      ).id
    end
    assert_no_difference("Crawling::PageSnapshot.count") do
      persister.call(scan: @scan, item: item, lease: lease, result: fetched)
    end
  end

  private

  def create_robots_snapshot
    Crawling::RobotsSnapshot.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      origin: "https://example.com",
      origin_digest: Digest::SHA256.hexdigest("https://example.com"),
      source_url: "https://example.com/robots.txt",
      final_url: "https://example.com/robots.txt",
      retrieval_status: "fetched",
      http_status: 200,
      retrieved_at: @now,
      artifact_sha256: Digest::SHA256.hexdigest("User-agent: *\nAllow: /\n"),
      parser_version: Crawling::RobotsParser::VERSION,
      redirect_count: 0,
      groups: [],
      sitemap_urls: [],
      warnings: [],
      malformed: false
    )
  end

  def initialize_frontier(worker_id)
    Crawling::InitializeStaticCrawl.new(
      clock: -> { @now },
      robots_builder: ->(_scan) { Callable.new(@scan.robots_snapshots.sole) },
      sitemap_builder: ->(_scan) { Callable.new(nil) }
    ).call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      worker_id: worker_id
    )
  end

  def transport_limits
    Shared::NetworkSafety::TransportLimits.new(
      connect_timeout: 1,
      tls_timeout: 1,
      header_timeout: 1,
      body_timeout: 1,
      total_timeout: 10,
      max_header_bytes: 8.kilobytes,
      max_body_bytes: 128.kilobytes,
      max_decompressed_bytes: 256.kilobytes,
      max_decompression_ratio: 100
    )
  end

  def pressure_decision
    Crawling::FetchPermitDecision.new(
      state: "acquired",
      reason_code: nil,
      scope: nil,
      retry_at: nil,
      permit: Crawling::FetchPermitGrant.new(
        id: SecureRandom.uuid,
        token: SecureRandom.hex(32),
        host_key_digest: "a" * 64,
        expires_at: @now + 1.minute
      ),
      limits: Crawling::PressureLimits.new(
        global_concurrency: 10,
        organization_concurrency: 10,
        scan_concurrency: 2,
        host_concurrency: 2,
        global_rate: 100,
        organization_rate: 100,
        scan_rate: 10,
        host_rate: 10,
        permit_duration: 60,
        scan_deadline: @now + 1.hour
      )
    )
  end
end
