# frozen_string_literal: true

require "test_helper"

class CrawlingPageRenderingTest < ActiveSupport::TestCase
  Renderer = Struct.new(:result, :error, :calls) do
    def call(**attributes)
      calls << attributes
      raise error if error

      result
    end
  end

  setup do
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "page-render-owner")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "page-render-project")
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
        "max_urls" => 20,
        "max_depth" => 3,
        "query_handling" => "all",
        "query_parameter_allowlist" => [],
        "query_parameter_denylist" => [],
        "rendering_sample_percent" => 100,
        "max_rendered_pages" => 1,
        "artifact_retention_days" => 2,
        "robots_behavior" => "respect"
      },
      entitlement_snapshot: {
        "crawl.manual" => true,
        "crawl.max_urls_per_scan" => 500,
        "credit_estimate" => { "rendered_pages" => 1 }
      }
    )
    @scan = run_scan_to(@scan, "running", at: @now - 30.seconds)
    @store = TestSupport::FakeArtifactStore.new
  end

  test "deterministically schedules one tenant-exact render within the settings and plan cap" do
    first = completed_source("https://example.com/one", "<!doctype html><title>One</title>")
    second = completed_source("https://example.com/two", "<!doctype html><title>Two</title>")
    enqueued = []
    scheduler = Crawling::SchedulePageRender.new(
      clock: -> { @now },
      enqueuer: ->(render) { enqueued << render.id },
      settings: Rails.application.config.x.searchops
    )

    render = scheduler.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      page_snapshot_id: first.id
    )
    replay = scheduler.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      page_snapshot_id: first.id
    )
    capped = scheduler.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      page_snapshot_id: second.id
    )

    assert_same_record render, replay
    assert_nil capped
    assert_equal [ render.id ], enqueued
    assert_equal first.id, render.page_snapshot_id
    assert_equal first.page_fact.id, render.page_fact_id
    assert_equal first.fetch_result.final_url, render.requested_url
    assert_equal Digest::SHA256.hexdigest(render.requested_url), render.requested_url_digest
    assert render.screenshot_enabled?
    assert_equal 1, Crawling::PageRender.where(scan_id: @scan.id).count

    foreign = create_organization_for(slug: "page-render-foreign")
    error = assert_raises(Crawling::AccessDenied) do
      scheduler.call(
        organization_id: foreign.organization.id,
        scan_id: @scan.id,
        page_snapshot_id: first.id
      )
    end
    assert_equal "page_render_scope_unavailable", error.reason_code

    substituted = render.attributes.except("id", "created_at", "updated_at").merge(
      "organization_id" => foreign.organization.id,
      "created_at" => @now,
      "updated_at" => @now
    )
    assert_raises(ActiveRecord::StatementInvalid) do
      Crawling::PageRender.transaction(requires_new: true) do
        Crawling::PageRender.insert!(substituted)
      end
    end
  end

  test "persists rendered DOM screenshot provenance facts and links and meters only accepted work" do
    source = completed_source("https://example.com/source", "<!doctype html><title>Static</title>")
    render = schedule(source)
    rendered_dom = <<~HTML
      <!doctype html><html lang="en"><head><title>Rendered</title></head>
      <body><h1>Client content</h1><a href="/client-link">Client link</a></body></html>
    HTML
    result = render_result(dom: rendered_dom, screenshot: "synthetic-png".b)
    renderer = Renderer.new(result, nil, [])
    usage = []
    service = Crawling::RenderPage.new(
      clock: -> { @now },
      renderer: renderer,
      artifact_capture: artifact_capture,
      usage_starter: ->(**attributes) { usage << [ :start, attributes ]; true },
      usage_finisher: ->(**attributes) { usage << [ :finish, attributes ]; true }
    )

    completed = service.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      page_render_id: render.id,
      worker_id: "render-test-1"
    )

    assert completed.completed?
    assert_equal "https://example.com/source", completed.final_url
    assert_equal Digest::SHA256.hexdigest(rendered_dom), completed.rendered_dom_sha256
    assert_equal "ferrum-render-1.0", completed.renderer_version
    assert_equal "0.18.0", completed.ferrum_version
    assert_equal "Chrome/152.0.7977.75", completed.browser_product
    assert_equal "@fixture-revision", completed.browser_revision
    assert_equal "1.3", completed.protocol_version
    assert completed.rendered_dom_artifact.downloadable?
    assert completed.screenshot_artifact.downloadable?
    assert_equal "Rendered", completed.rendered_page_fact.facts.fetch("title_summary")
    assert_equal 1, completed.rendered_links.count
    assert_equal "https://example.com/client-link", completed.rendered_links.sole.destination_url
    assert_equal 0, source.crawl_links.count
    assert_equal [ :start, :finish ], usage.map(&:first)
    assert_equal "rendered_page", usage.first.last.fetch(:operation_kind)
    assert_equal "accepted", usage.last.last.fetch(:outcome)
    assert_raises(ActiveRecord::StatementInvalid) do
      Crawling::PageRender.transaction(requires_new: true) do
        completed.update_column(:requested_url, "https://example.com/changed")
      end
    end

    assert_no_difference [ "Crawling::RenderedPageFact.count", "Crawling::RenderedLink.count",
      "Crawling::Artifact.count" ] do
      assert service.call(
        organization_id: @scan.organization_id,
        scan_id: @scan.id,
        page_render_id: render.id,
        worker_id: "render-test-replay"
      ).completed?
    end
    assert_equal 2, usage.length
  end

  test "timeout and browser crash release attempts while cancellation is terminal" do
    timeout_render = schedule(completed_source(
      "https://example.com/timeout", "<!doctype html><title>Timeout</title>"
    ))
    usage = []
    timeout_service = failing_service(
      Crawling::RenderError.new(reason_code: "render_timeout", transient: true), usage
    )
    timed_out = timeout_service.call(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      page_render_id: timeout_render.id,
      worker_id: "render-timeout"
    )

    assert timed_out.pending?
    assert_equal "render_timeout", timed_out.failure_category
    assert_equal "failed", usage.last.last.fetch(:outcome)

    crashed = nil
    2.times do |index|
      timed_out.reload.update!(next_attempt_at: @now)
      crashed = failing_service(
        Crawling::RenderError.new(reason_code: "browser_crashed", transient: true), usage
      ).call(
        organization_id: @scan.organization_id,
        scan_id: @scan.id,
        page_render_id: timed_out.id,
        worker_id: "render-crash-#{index}"
      )
    end
    assert crashed.failed?
    assert_equal "browser_crashed", crashed.failure_category

    other_scan = rendering_scan("page-render-cancel")
    source = completed_source(
      "https://example.com/cancel", "<!doctype html><title>Cancel</title>", scan: other_scan
    )
    canceled_render = schedule(source, scan: other_scan)
    canceled = failing_service(
      Crawling::RenderError.new(reason_code: "render_canceled"), usage
    ).call(
      organization_id: other_scan.organization_id,
      scan_id: other_scan.id,
      page_render_id: canceled_render.id,
      worker_id: "render-cancel"
    )
    assert canceled.canceled?
    assert_equal "canceled", usage.last.last.fetch(:outcome)
  end

  test "expired browser lease is recovered once and render health stays bounded" do
    render = schedule(completed_source(
      "https://example.com/recover", "<!doctype html><title>Recover</title>"
    ))
    render.update!(
      state: "processing",
      attempts: 1,
      worker_id: "crashed-render-worker",
      lease_token_digest: Digest::SHA256.hexdigest("crashed-token"),
      started_at: @now - 10.minutes,
      lease_expires_at: @now - 1.minute,
      next_attempt_at: nil
    )
    jobs = []
    service = Crawling::RecoverStaticCrawlWork.new(
      clock: -> { @now },
      crawl_enqueuer: ->(*) { },
      extraction_enqueuer: ->(*) { },
      render_enqueuer: ->(*ids) { jobs << ids }
    )

    assert service.call
    assert render.reload.pending?
    assert_equal "render_lease_expired", render.failure_category
    assert_equal [ [ render.organization_id, render.scan_id, render.id ] ], jobs
    metrics = Crawling::Public.render_metrics(organization_id: @scan.organization_id, clock: -> { @now })
    assert_equal 1, metrics.pending_count
    assert_equal 0, metrics.processing_count
    assert_equal 0, metrics.stale_count
  end

  private

  def rendering_scan(slug)
    owner = create_organization_for(slug: slug)
    enable_project_limit(owner)
    enable_property_limits(owner)
    project = create_project_for(owner, slug: "#{slug}-project")
    property = create_property_for(owner, project: project, configuration: { origin: "https://example.com" })
    scan = create_scan_for(
      owner,
      project: project,
      property: property,
      at: @now - 1.minute,
      settings_snapshot: @scan.settings_snapshot,
      entitlement_snapshot: @scan.entitlement_snapshot
    )
    run_scan_to(scan, "running", at: @now - 30.seconds)
  end

  def completed_source(url, body, scan: @scan)
    original_scan = @scan
    @scan = scan
    snapshot = create_snapshot(url, body)
    Crawling::ExtractStaticPageLinks.new(clock: -> { @now }, store: @store).call(
      organization_id: scan.organization_id,
      scan_id: scan.id,
      page_snapshot_id: snapshot.id,
      worker_id: "source-extraction"
    )
  ensure
    @scan = original_scan
  end

  def create_snapshot(url, body)
    item = Crawling::Public.discover_frontier(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      entries: [ Crawling::Public.frontier_entry(url: url, depth: 0, discovery_source: "seed") ],
      clock: -> { @now }
    ).items.sole
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
    token = SecureRandom.hex(32)
    item.update!(attempts: 1)
    result = create_crawl_fetch_result_for(
      scan: @scan,
      crawl_url: item,
      lease_token: token,
      at: @now,
      body: body,
      artifact_id: artifact.artifact_id
    )
    item.update!(
      state: "succeeded",
      next_attempt_at: nil,
      last_lease_token_digest: Digest::SHA256.hexdigest(token),
      last_lease_outcome: "succeeded",
      fetch_result_id: result.id,
      http_status_code: 200,
      completed_at: @now
    )
    Crawling::PageSnapshot.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      crawl_url_id: item.id,
      crawl_fetch_result_id: result.id,
      artifact_id: artifact.artifact_id,
      state: "pending",
      maximum_extraction_attempts: 3,
      next_attempt_at: @now
    )
  end

  def schedule(snapshot, scan: @scan)
    Crawling::SchedulePageRender.new(
      clock: -> { @now }, enqueuer: ->(*) { }, settings: Rails.application.config.x.searchops
    ).call(organization_id: scan.organization_id, scan_id: scan.id, page_snapshot_id: snapshot.id)
  end

  def render_result(dom:, screenshot: nil)
    Crawling::RenderResult.new(
      final_url: "https://example.com/source",
      dom: dom,
      screenshot: screenshot,
      duration_ms: 125,
      request_count: 3,
      response_bytes: 4096,
      console_messages: [ "log: ready" ],
      page_errors: [],
      network_summary: { "response_count" => 3, "response_bytes" => 4096 },
      renderer_version: "ferrum-render-1.0",
      ferrum_version: "0.18.0",
      browser_product: "Chrome/152.0.7977.75",
      browser_revision: "@fixture-revision",
      protocol_version: "1.3"
    )
  end

  def artifact_capture
    lambda do |**attributes|
      Crawling::CaptureArtifact.new(store: @store, clock: -> { @now }).call(**attributes)
    end
  end

  def failing_service(error, usage)
    Crawling::RenderPage.new(
      clock: -> { @now },
      renderer: Renderer.new(nil, error, []),
      artifact_capture: artifact_capture,
      usage_starter: ->(**attributes) { usage << [ :start, attributes ]; true },
      usage_finisher: ->(**attributes) { usage << [ :finish, attributes ]; true }
    )
  end

  def assert_same_record(expected, actual)
    assert_equal [ expected.class, expected.id ], [ actual.class, actual.id ]
  end
end

class CrawlingFerrumPageRendererTest < ActiveSupport::TestCase
  class AllowFixtureDestination
    def authorize!(url:)
      URI.parse(url)
      true
    end
  end

  test "renders a local JavaScript fixture in a fresh browser context with exact provenance" do
    skip "Chromium integration requires /usr/bin/chromium" unless File.executable?("/usr/bin/chromium")

    fixture = TestSupport::Network::JavascriptHttpFixture.new.start
    settings = Rails.application.config.x.searchops.to_h.merge(
      process_role: "worker_render",
      browser_timeout: 15,
      browser_max_requests: 20,
      browser_max_response_bytes: 1.megabyte,
      crawler_dns_timeout: 1
    )
    # Docker's default seccomp profile blocks the user-namespace syscall used by
    # Chromium's sandbox in this generic test container. Production never passes
    # this test-only flag; the dedicated render runtime keeps sandboxing enabled.
    pool = Crawling::FerrumBrowserPool.new(settings: settings, browser_options: { "no-sandbox" => nil })
    renderer = Crawling::FerrumPageRenderer.new(
      settings: settings,
      browser_pool: pool,
      destination_policy: AllowFixtureDestination.new
    )

    result = renderer.call(url: fixture.url, screenshot: true)

    assert_includes result.dom, "Rendered fixture"
    assert_includes result.dom, "javascript executed"
    assert_includes result.dom, "/client-link"
    assert result.screenshot.start_with?("\x89PNG".b)
    assert result.console_messages.any? { |message| message.include?("fixture-ready") }
    assert_match(/Chrom(?:e|ium)\//, result.browser_product)
    assert_equal "0.18.0", result.ferrum_version
    assert_equal "ferrum-render-1.0", result.renderer_version
    assert result.request_count.between?(1, 20)
    assert_operator result.response_bytes, :>, 0
  ensure
    pool&.recycle
    fixture&.stop
  end

  test "refuses browser execution in web and default workers" do
    settings = Rails.application.config.x.searchops.to_h.merge(process_role: "worker_default")
    renderer = Crawling::FerrumPageRenderer.new(
      settings: settings,
      browser_pool: Object.new,
      destination_policy: AllowFixtureDestination.new
    )

    assert_raises(Shared::Public::SecurityRejectedJobError) do
      renderer.call(url: "https://example.com", screenshot: false)
    end
  end
end
