# frozen_string_literal: true

require "test_helper"

class CrawlingPolicyTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "crawl-policy-domain")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    enable_crawl_policy(@owner)
    @project = create_project_for(@owner, slug: "crawl-policy-project")
    @property = create_property_for(
      @owner, project: @project,
      configuration: { origin: "https://www.example.com" }
    )
    @environment = @property.environments.sole
  end

  test "shows plan-safe defaults and saves normalized immutable versions" do
    view = policy

    refute view.persisted?
    assert_equal 0, view.version
    assert_equal 25, view.configuration.max_urls
    assert_equal [ "https://www.example.com/" ], view.configuration.start_urls
    assert_equal 14, view.configuration.artifact_retention_days

    first = configure
    second = configure(max_depth: 8, user_agent_suffix: "AcmeBot")

    assert_equal [ 1, 2 ], [ first.version, second.version ]
    assert_equal "https://www.example.com/docs?utm_source=test", first.start_urls.second
    assert_equal "SearchOpsBot/1.0 AcmeAudit", first.configuration.effective_user_agent
    assert_equal 5, first.max_depth
    assert_equal 8, second.max_depth
    assert first.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { first.update!(max_depth: 9) }
    assert_equal 2, policy.version
    assert_equal 2, Auditing::AuditEvent.where(
      organization_id: @owner.organization.id, action: "crawl_policy.updated"
    ).count
  end

  test "rejects URLs outside the exact origin and ambiguous URL forms" do
    invalid_urls = [
      "https://other.example.com/",
      "https://user:pass@www.example.com/",
      "https://www.example.com/page#fragment",
      "ftp://www.example.com/file"
    ]

    invalid_urls.each do |url|
      error = assert_raises(Crawling::Invalid) do
        configure(start_urls: url)
      end
      assert_includes error.field_errors[:start_urls].join, "Every URL"
    end
    assert_equal 0, Crawling::PolicyVersion.count
  end

  test "enforces global and plan limits without reserving credits" do
    assert_equal 25, policy.limits.max_urls

    assert_no_difference([ "Crawling::PolicyVersion.count", "Usage::QuotaReservation.count" ]) do
      error = assert_raises(Crawling::Invalid) { configure(max_urls: 26) }
      assert_equal [ "Enter a value between 1 and 25." ], error.field_errors[:max_urls]
    end

    error = assert_raises(Crawling::Invalid) do
      configure(max_concurrency: 2)
    end
    assert_equal [ "Enter a value between 1 and 1." ], error.field_errors[:max_concurrency]
  end

  test "gates rendering custom patterns and user-agent suffix by effective plan" do
    limited = create_organization_for(slug: "crawl-policy-limited")
    enable_project_limit(limited)
    enable_property_limits(limited)
    enable_crawl_policy(limited, values: {
      "crawl.javascript_rendering" => [ "boolean", false ],
      "crawl.max_rendered_pages_per_scan" => [ "integer", 0 ],
      "crawl.custom_user_agent" => [ "boolean", false ],
      "crawl.custom_rules" => [ "boolean", false ]
    })
    project = create_project_for(limited, slug: "limited-policy-project")
    property = create_property_for(limited, project: project)
    environment = property.environments.sole

    error = assert_raises(Crawling::Invalid) do
      Crawling::Public.configure_policy(
        actor_membership: limited.membership,
        project_id: project.id,
        property_id: property.id,
        environment_id: environment.id,
        attributes: valid_crawl_policy_attributes(origin: environment.origin)
      )
    end

    assert error.field_errors.key?(:include_patterns)
    assert error.field_errors.key?(:user_agent_suffix)
    assert error.field_errors.key?(:max_rendered_pages)
  end

  test "reset creates a plan-safe version and an audit record" do
    configure(max_urls: 10, max_rendered_pages: 2, artifact_retention_days: 3)

    reset = Crawling::Public.reset_policy(**scope)

    assert_equal 2, reset.version
    assert_equal 25, reset.max_urls
    assert_equal 14, reset.artifact_retention_days
    audit = Auditing::AuditEvent.find_by!(
      organization_id: @owner.organization.id,
      action: "crawl_policy.reset",
      target_id: reset.crawl_policy_set_id
    )
    assert_equal "reset", audit.metadata.fetch("operation")
  end

  test "snapshot is idempotent and remains exact after policy changes" do
    first = configure(max_urls: 10, max_depth: 3, max_rendered_pages: 2)
    scan_id = create_scan_for(
      @owner, project: @project, property: @property, environment: @environment
    ).id

    snapshot = Crawling::Public.snapshot_for_scan(**scope, scan_id: scan_id)
    retry_snapshot = Crawling::Public.snapshot_for_scan(**scope, scan_id: scan_id)
    configure(max_urls: 20, max_depth: 9)

    assert_equal snapshot.id, retry_snapshot.id
    assert_equal first.id, snapshot.crawl_policy_version_id
    assert_equal 10, snapshot.configuration.fetch("max_urls")
    assert_equal 3, snapshot.configuration.fetch("max_depth")
    assert_equal Digest::SHA256.hexdigest(JSON.generate(snapshot.configuration.sort.to_h)),
      snapshot.configuration_digest
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      snapshot.update!(configuration: snapshot.configuration.merge("max_urls" => 20))
    end
    assert_equal 10, snapshot.reload.configuration.fetch("max_urls")
  end

  test "cross-tenant policy and scan identifiers fail closed" do
    configure
    snapshot_scan = create_scan_for(
      @owner, project: @project, property: @property, environment: @environment
    )
    snapshot = Crawling::Public.snapshot_for_scan(**scope, scan_id: snapshot_scan.id)
    foreign = create_organization_for(slug: "crawl-policy-foreign")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    enable_crawl_policy(foreign)
    foreign_project = create_project_for(foreign, slug: "foreign-policy-project")
    foreign_property = create_property_for(foreign, project: foreign_project)
    foreign_environment = foreign_property.environments.sole

    assert_raises(Crawling::AccessDenied) do
      Crawling::Public.policy(
        actor_membership: @owner.membership,
        project_id: foreign_project.id,
        property_id: foreign_property.id,
        environment_id: foreign_environment.id
      )
    end
    assert_raises(Crawling::AccessDenied) do
      Crawling::Public.snapshot_for_scan(
        actor_membership: foreign.membership,
        project_id: foreign_project.id,
        property_id: foreign_property.id,
        environment_id: foreign_environment.id,
        scan_id: snapshot.scan_id
      )
    end
  end

  private

  def policy
    Crawling::Public.policy(**scope)
  end

  def configure(**overrides)
    Crawling::Public.configure_policy(
      **scope,
      attributes: valid_crawl_policy_attributes(origin: @environment.origin, **overrides)
    )
  end

  def scope
    {
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id
    }
  end
end
