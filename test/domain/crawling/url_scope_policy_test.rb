# frozen_string_literal: true

require "test_helper"

class CrawlingUrlScopePolicyTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
  end

  test "allows exact origin and explicitly configured hosts but rejects sibling lookalikes" do
    policy = scope_policy(allowed_hosts: [ "cdn.example.com" ])

    assert_decision policy, "https://example.com/docs/start", true, "same_origin"
    assert_decision policy, "https://cdn.example.com/docs/asset", true, "allowed_host"
    assert_decision policy, "https://www.example.com/docs/start", false, "host_out_of_scope"
    assert_decision policy, "https://notexample.com/docs/start", false, "host_out_of_scope"
    assert_decision policy, "https://example.com.evil.test/docs/start", false, "host_out_of_scope"
    assert_decision policy, "http://example.com/docs/start", false, "scheme_out_of_scope"
    assert_decision policy, "https://example.com:8443/docs/start", false, "port_out_of_scope"
  end

  test "exclude wins over include and matching uses the normalized encoded path boundary" do
    policy = scope_policy(
      include_patterns: [ "/docs/**", "/private/**" ],
      exclude_patterns: [ "/docs/private/**", "/private/**" ]
    )

    assert_decision policy, "https://example.com/docs/guide", true, "same_origin"
    assert_decision policy, "https://example.com/docs/private/key", false, "path_excluded"
    assert_decision policy, "https://example.com/docs/%2E%2E/private/key", false, "path_excluded"
    assert_decision policy, "https://example.com/docs%2Fprivate/key", false, "path_not_included"
    assert_decision policy, "https://example.com/public", false, "path_not_included"
  end

  test "depth is bounded before URL admission" do
    policy = scope_policy(max_depth: 2)

    assert_decision policy, "https://example.com/", true, "same_origin", depth: 2
    assert_decision policy, "https://example.com/", false, "depth_exceeded", depth: 3
    assert_decision policy, "https://example.com/", false, "depth_invalid", depth: -1
    assert_decision policy, "https://example.com/", false, "depth_invalid", depth: "one"
    assert_decision policy, "https://example.com/", false, "depth_invalid", depth: 1.5
    assert_decision policy, "not a URL", false, "url_invalid"
  end

  test "an HTML canonical recommendation never expands crawl authorization" do
    policy = scope_policy
    html_canonical_observation = "https://example.com.evil.test/docs"

    decision = policy.evaluate(url: html_canonical_observation, depth: 0)

    refute decision.allowed?
    assert_equal "host_out_of_scope", decision.reason_code
  end

  test "scan scope resolution requires the exact tenant and uses its immutable settings" do
    owner = create_organization_for(slug: "url-scope-owner")
    enable_project_limit(owner)
    enable_property_limits(owner)
    project = create_project_for(owner, slug: "url-scope-project")
    property = create_property_for(
      owner,
      project: project,
      configuration: { origin: "https://example.com" }
    )
    scan = create_scan_for(
      owner,
      project: project,
      property: property,
      settings_snapshot: {
        "max_depth" => 1,
        "include_patterns" => [ "/docs/**" ],
        "exclude_patterns" => [],
        "query_handling" => "tracking_only",
        "query_parameter_allowlist" => [],
        "query_parameter_denylist" => [ "session_id" ]
      }
    )
    foreign = create_organization_for(slug: "url-scope-foreign")

    policy = Crawling::Public.url_scope_for_scan(
      organization_id: owner.organization.id,
      scan_id: scan.id
    )

    allowed = policy.evaluate(
      url: "https://example.com/docs/page?utm_source=x&id=7&session_id=hidden",
      depth: 1
    )
    assert allowed.allowed?
    assert_equal "https://example.com/docs/page?id=7", allowed.normalized_url.identity_url
    assert_raises(Crawling::AccessDenied) do
      Crawling::Public.url_scope_for_scan(
        organization_id: foreign.organization.id,
        scan_id: scan.id
      )
    end
  end

  private

  def scope_policy(**overrides)
    Crawling::Public.url_scope_policy(
      origin: "https://example.com",
      allowed_hosts: [],
      include_patterns: [],
      exclude_patterns: [],
      max_depth: 5,
      **overrides
    )
  end

  def assert_decision(policy, url, allowed, reason, depth: 0)
    decision = policy.evaluate(url: url, depth: depth)
    assert_equal allowed, decision.allowed?, url
    assert_equal reason, decision.reason_code, url
  end
end
