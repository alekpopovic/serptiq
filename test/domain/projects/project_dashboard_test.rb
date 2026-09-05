# frozen_string_literal: true

require "test_helper"

class ProjectsProjectDashboardTest < ActiveSupport::TestCase
  setup do
    sync_usage_catalog
    @owner = create_organization_for(slug: "project-dashboard-domain")
    enable_onboarding_entitlements(@owner, projects: 10, websites: 10, mobile: 10)
    set_onboarding_entitlement(@owner, "crawl.credits_monthly", 500, at: Time.current)
    @project = create_project_for(@owner, slug: "dashboard-domain-project")
    @policy = Authorization::PolicyAdapter.new(
      actor_membership: @owner.membership,
      organization: @owner.organization
    )
  end

  test "observation contract distinguishes every explicit display state" do
    Projects::DashboardObservation.states.each do |state|
      observation = Projects::DashboardObservation.new(kind: "scan", state: state)
      assert_equal state, observation.state
      assert_predicate observation, "#{state}?"
      assert_predicate observation.label, :present?
      assert_predicate observation.detail, :present?
    end

    assert_raises(ArgumentError) do
      Projects::DashboardObservation.new(kind: "scan", state: "probably_ready")
    end
  end

  test "real property readiness and activity are tenant scoped and bounded" do
    property = create_property_for(
      @owner,
      project: @project,
      display_name: "Dashboard Website",
      configuration: { origin: "https://dashboard.example.com" }
    )
    property.update!(verification_status: "verified", verified_at: Time.current)

    readiness = Properties::Public.project_readiness(
      actor_membership: @owner.membership,
      project_id: @project.id
    )
    page = Properties::Public.property_page(
      actor_membership: @owner.membership,
      project_id: @project.id
    )
    activity = Auditing::Public.project_activity(
      organization_id: @owner.organization.id,
      project_id: @project.id,
      authorization: decision("projects.read", project: @project)
    )

    assert_equal 1, readiness.website_count
    assert_equal 1, readiness.verified_website_count
    assert_equal 1, readiness.primary_environment_count
    assert_equal [ "Production" ], page.entries.sole.environments.map(&:display_name)
    assert_equal "project.created", activity.entries.last.action

    foreign = create_organization_for(slug: "project-dashboard-foreign")
    assert_raises(Auditing::AccessDenied) do
      Auditing::Public.project_activity(
        organization_id: foreign.organization.id,
        project_id: @project.id,
        authorization: decision("projects.read", project: @project)
      )
    end
  end

  test "dashboard composes access entitlement quota and real provider readiness" do
    property = create_property_for(@owner, project: @project)
    property.update!(verification_status: "verified", verified_at: Time.current)
    grant = Integrations::SearchConsole::ConnectionGrant.new(
      external_account_id: "dashboard-provider-account",
      granted_scopes: [ Integrations::SearchConsole::READONLY_SCOPE ],
      consented_at: Time.current,
      consent_reference: SecureRandom.urlsafe_base64(48, false)
    )
    Integrations::Public.register_search_console_connection(
      actor_membership: @owner.membership,
      grant: grant
    )
    page = Properties::Public.property_page(
      actor_membership: @owner.membership,
      project_id: @project.id
    )
    readiness = Properties::Public.project_readiness(
      actor_membership: @owner.membership,
      project_id: @project.id
    )
    usage = Usage::Public.project_readiness(
      organization_id: @owner.organization.id,
      project_id: @project.id,
      authorization: decision("usage.read", project: @project)
    )
    integration = Integrations::Public.dashboard_readiness(
      organization_id: @owner.organization.id,
      authorization: decision("integrations.read")
    )
    dashboard = Projects::Public.build_dashboard(
      project: project_summary,
      property_page: page,
      property_readiness: readiness,
      scan_read: decision("scans.read", project: @project),
      findings_read: decision("findings.read", project: @project),
      scan_access: scan_access,
      usage: usage,
      integration: integration,
      activity_page: activity_page
    )

    assert_predicate dashboard.scan_action, :allowed?
    assert_predicate dashboard.scan_observation, :no_data?
    assert_predicate dashboard.findings_observation, :no_data?
    assert_equal "connected", dashboard.integration.state
    assert dashboard.checklist.all?(&:ready?)
  end

  test "project usage proof cannot be replayed across projects or tenants" do
    other_project = create_project_for(@owner, slug: "dashboard-other-project")
    authorization = decision("usage.read", project: @project)

    assert_raises(Usage::AccessDenied) do
      Usage::Public.project_readiness(
        organization_id: @owner.organization.id,
        project_id: other_project.id,
        authorization: authorization
      )
    end
    foreign = create_organization_for(slug: "dashboard-usage-foreign")
    assert_raises(Usage::AccessDenied) do
      Usage::Public.project_readiness(
        organization_id: foreign.organization.id,
        project_id: @project.id,
        authorization: authorization
      )
    end
  end

  test "dashboard property and environment query count stays constant as the project grows" do
    create_property_for(@owner, project: @project, kind: "website")
    one_count = query_count { load_dashboard }

    5.times do |index|
      create_property_for(
        @owner,
        project: @project,
        kind: index.even? ? "website" : "android_app"
      )
    end
    many_count = query_count { load_dashboard }

    assert_equal one_count, many_count
  end

  private

  def decision(permission, project: nil)
    @policy.decision(permission_key: permission, project: project)
  end

  def scan_access
    @policy.access_decision(
      permission_key: "scans.run",
      project: @project,
      entitlement_key: "crawl.manual",
      resource: Authorization::ResourceContext.new(
        id: @project.id,
        type: "project",
        organization_id: @owner.organization.id,
        scope_type: "Project",
        scope_id: @project.id
      )
    )
  end

  def project_summary
    Projects::Public.project_details(
      actor_membership: @owner.membership,
      project_id: @project.id,
      read_models: Properties::Public.project_rollup_reader
    )
  end

  def activity_page
    Auditing::Public.project_activity(
      organization_id: @owner.organization.id,
      project_id: @project.id,
      authorization: decision("projects.read", project: @project)
    )
  end

  def load_dashboard
    Current.entitlement_cache = nil
    page = Properties::Public.property_page(
      actor_membership: @owner.membership,
      project_id: @project.id
    )
    readiness = Properties::Public.project_readiness(
      actor_membership: @owner.membership,
      project_id: @project.id
    )
    Projects::Public.build_dashboard(
      project: project_summary,
      property_page: page,
      property_readiness: readiness,
      scan_read: decision("scans.read", project: @project),
      findings_read: decision("findings.read", project: @project),
      scan_access: scan_access,
      usage: Usage::Public.project_readiness(
        organization_id: @owner.organization.id,
        project_id: @project.id,
        authorization: decision("usage.read", project: @project)
      ),
      integration: Integrations::Public.dashboard_readiness(
        organization_id: @owner.organization.id,
        authorization: decision("integrations.read")
      ),
      activity_page: activity_page
    )
  end

  def query_count
    count = 0
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      sql = payload[:sql].to_s
      count += 1 if payload[:name] != "SCHEMA" && sql.match?(/\ASELECT/i)
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    count
  end
end
