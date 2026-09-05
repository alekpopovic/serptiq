# frozen_string_literal: true

require "test_helper"

class CrawlingRobotsPolicyTest < ActiveSupport::TestCase
  FakeRetriever = Struct.new(:results, :calls, keyword_init: true) do
    def call(origin:)
      calls << origin.origin
      results.shift || raise("unexpected robots retrieval")
    end
  end

  setup do
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "robots-owner")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "robots-project")
    @property = create_property_for(
      @owner,
      project: @project,
      configuration: { origin: "https://example.com" }
    )
  end

  test "caches one immutable tenant-bound snapshot and reuses it idempotently" do
    scan = queued_scan
    retriever = fake_retriever(fetched(<<~ROBOTS))
      User-agent: SearchOpsBot
      Disallow: /private
      Allow: /private/public
      Sitemap: https://example.com/sitemap.xml
    ROBOTS
    service = Crawling::CacheRobotsPolicy.new(retriever: retriever)

    snapshot = service.call(organization_id: @owner.organization.id, scan_id: scan.id)
    replay = service.call(organization_id: @owner.organization.id, scan_id: scan.id)

    assert_equal snapshot.id, replay.id
    assert_equal [ "https://example.com" ], retriever.calls
    assert_equal "fetched", snapshot.retrieval_status
    assert_equal Digest::SHA256.hexdigest("https://example.com"), snapshot.origin_digest
    assert_equal Digest::SHA256.hexdigest(fetched_body), snapshot.artifact_sha256
    assert_equal 1, snapshot.parser_version
    assert_equal [ "https://example.com/sitemap.xml" ], snapshot.sitemap_urls
    assert snapshot.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { snapshot.update!(retrieval_status: "unavailable") }
  end

  test "evaluates explicit precedence with stable source provenance and exact tenant isolation" do
    scan = queued_scan
    snapshot = cache(scan, <<~ROBOTS)
      User-agent: *
      Disallow: /
      User-agent: SearchOpsBot
      Disallow: /private
      Allow: /private/public
    ROBOTS

    denied = evaluate(scan, "https://example.com/private/report")
    allowed = evaluate(scan, "https://example.com/private/public/report")
    ordinary = evaluate(scan, "https://example.com/docs")

    assert_equal [ "denied", "explicit_disallow" ], [ denied.outcome, denied.reason_code ]
    assert_equal [ "allowed", "explicit_allow" ], [ allowed.outcome, allowed.reason_code ]
    assert_equal [ "allowed", "no_matching_rule" ], [ ordinary.outcome, ordinary.reason_code ]
    assert_equal snapshot.id, denied.snapshot_id
    assert_equal snapshot.artifact_sha256, denied.artifact_sha256
    assert_equal 1, denied.parser_version
    assert_equal "/private", denied.matched_rule.fetch("pattern")
    assert_equal 4, denied.matched_rule.fetch("line_number")

    foreign = create_organization_for(slug: "robots-foreign")
    assert_raises(Crawling::AccessDenied) do
      Crawling::Public.evaluate_robots_policy(
        organization_id: foreign.organization.id,
        scan_id: scan.id,
        url: "https://example.com/private"
      )
    end
    assert_raises(Crawling::AccessDenied) do
      Crawling::Public.evaluate_robots_policy(
        organization_id: @owner.organization.id,
        scan_id: scan.id,
        url: "https://outside.example.net/private"
      )
    end
  end

  test "applies RFC status policy with fail-closed unknown outcomes" do
    {
      "unavailable" => [ "allowed", "robots_unavailable", 404 ],
      "unreachable" => [ "unknown", "robots_unreachable", 503 ],
      "oversized" => [ "unknown", "robots_oversized", nil ],
      "malformed" => [ "unknown", "robots_malformed", 200 ]
    }.each_with_index do |(status, (outcome, reason, http_status)), index|
      scan = queued_scan(at: @now + index.seconds)
      retrieval = retrieval(status: status, http_status: http_status)
      cache_with_result(scan, retrieval)

      decision = evaluate(scan, "https://example.com/path")
      assert_equal outcome, decision.outcome, status
      assert_equal reason, decision.reason_code, status
      assert_equal outcome == "allowed", decision.crawl_permitted?, status
    end
  end

  test "fails closed when a successful cached policy is older than 24 hours" do
    scan = queued_scan
    snapshot = cache(scan, "User-agent: *\nAllow: /\n")
    decision = Crawling::EvaluateRobotsPolicy.new(clock: -> { @now + 24.hours + 1.second }).call(
      organization_id: @owner.organization.id,
      scan_id: scan.id,
      url: "https://example.com/path"
    )

    assert_equal snapshot.id, decision.snapshot_id
    assert_equal [ "unknown", "robots_snapshot_stale" ], [ decision.outcome, decision.reason_code ]
    refute decision.crawl_permitted?
  end

  test "verified-owner override is explicit in the immutable scan policy but never trusts sitemap URLs" do
    scan = queued_scan(settings: {
      "max_urls" => 20,
      "robots_behavior" => "verified_owner_override"
    })
    cache(scan, <<~ROBOTS)
      User-agent: SearchOpsBot
      Disallow: /
      Sitemap: https://outside.example.net/sitemap.xml
      Sitemap: http://127.0.0.1/private.xml
    ROBOTS

    decision = evaluate(scan, "https://example.com/private")
    candidates = Crawling::Public.robots_sitemap_candidates(
      organization_id: @owner.organization.id,
      scan_id: scan.id
    )

    assert decision.allowed?
    assert_equal "verified_owner_override", decision.reason_code
    assert_equal [ "https://outside.example.net/sitemap.xml" ], candidates.map(&:url)
    assert candidates.none?(&:trusted?)
  end

  private

  def queued_scan(at: @now, settings: nil)
    scan = create_scan_for(
      @owner,
      project: @project,
      property: @property,
      at: at,
      settings_snapshot: settings || { "max_urls" => 20, "robots_behavior" => "respect" }
    )
    run_scan_to(scan, "queued", at: at)
  end

  def fetched(body)
    @fetched_body = body
    retrieval(
      status: "fetched",
      http_status: 200,
      body: body,
      artifact_sha256: Digest::SHA256.hexdigest(body),
      final_url: "https://example.com/robots.txt"
    )
  end

  def fetched_body
    @fetched_body
  end

  def retrieval(status:, http_status: nil, body: "", artifact_sha256: nil, final_url: nil)
    Crawling::RobotsRetrieval.new(
      status: status,
      http_status: http_status,
      retrieved_at: @now,
      artifact_sha256: artifact_sha256,
      source_url: "https://example.com/robots.txt",
      final_url: final_url,
      redirect_count: 0,
      error_code: status.in?(%w[unreachable oversized malformed]) ? "#{status}_test" : nil,
      body: body
    )
  end

  def fake_retriever(*results)
    FakeRetriever.new(results: results, calls: [])
  end

  def cache(scan, body)
    cache_with_result(scan, fetched(body))
  end

  def cache_with_result(scan, result)
    Crawling::CacheRobotsPolicy.new(retriever: fake_retriever(result)).call(
      organization_id: @owner.organization.id,
      scan_id: scan.id
    )
  end

  def evaluate(scan, url)
    Crawling::Public.evaluate_robots_policy(
      organization_id: @owner.organization.id,
      scan_id: scan.id,
      url: url
    )
  end
end
