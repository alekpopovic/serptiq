# frozen_string_literal: true

require "test_helper"

class CrawlFrontierQueryPlanTest < ActiveSupport::TestCase
  TERMINAL_ROWS = 10_000
  PENDING_ROWS = 500

  setup do
    Authorization::Public.sync_catalog
    @now = Time.current.change(usec: 0)
    @owner = create_organization_for(slug: "frontier-plan")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "frontier-plan-project")
    @property = create_property_for(@owner, project: @project)
    @scan = create_scan_for(@owner, project: @project, property: @property, at: @now - 2.seconds)
    @scan = run_scan_to(@scan, "queued", at: @now - 1.second)
    insert_representative_rows
  end

  test "representative fair lease plan uses a partial frontier index" do
    plan = Crawling::FrontierLeaseQuery.new.explain(limit: 10, at: @now)
    plan_text = plan.is_a?(String) ? plan : JSON.generate(plan)
    warn plan_text if ENV["SEARCHOPS_EXPLAIN_FRONTIER"] == "1"

    assert_match(/index_crawl_urls_on_pending_(eligibility|fairness)/, plan_text)
    refute_match(/"Node Type":"Seq Scan","Parallel Aware":false,"Async Capable":false,"Relation Name":"crawl_urls"/,
      plan_text)
  end

  private

  def insert_representative_rows
    rows = (TERMINAL_ROWS + PENDING_ROWS).times.map do |index|
      pending = index >= TERMINAL_ROWS
      url = "https://host-#{index % 25}.example.com/page-#{index}"
      digest = Digest::SHA256.hexdigest("crawl-url:v1:#{url}")
      token_digest = Digest::SHA256.hexdigest("lease-#{index}")
      {
        organization_id: @scan.organization_id,
        project_id: @scan.project_id,
        property_id: @scan.property_id,
        environment_id: @scan.environment_id,
        scan_id: @scan.id,
        fetch_url: url,
        normalized_url_digest: digest,
        normalization_version: 1,
        normalized_url: url,
        host_digest: Digest::SHA256.hexdigest("crawl-host:v1:host-#{index % 25}.example.com"),
        depth: index % 5,
        priority: index % 20,
        discovery_source: "seed",
        state: pending ? "pending" : "succeeded",
        attempts: pending ? 0 : 1,
        maximum_attempts: 3,
        next_attempt_at: pending ? @now : nil,
        last_lease_token_digest: pending ? nil : token_digest,
        last_lease_outcome: pending ? nil : "succeeded",
        fetch_result_id: pending ? nil : index + 1,
        completed_at: pending ? nil : @now - 1.minute,
        created_at: @now - 2.minutes,
        updated_at: @now - 1.minute
      }
    end
    rows.each_slice(1000) { |batch| Crawling::CrawlUrl.insert_all!(batch) }
    ActiveRecord::Base.connection.execute("ANALYZE crawl_urls")
  end
end
