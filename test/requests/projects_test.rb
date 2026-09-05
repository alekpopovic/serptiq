# frozen_string_literal: true

require "test_helper"

class ProjectsRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @user = create_identity_user(display_name: "Project Owner")
    @owner = create_organization_for(user: @user, name: "Project Workspace", slug: "project-workspace")
    enable_project_limit(@owner, limit: 40)
    @issued = issue_identity_session(user: @user)
    authenticate_request(@issued)
  end

  test "owner creates updates searches archives and reactivates a project" do
    assert_difference("Projects::Project.count", 1) do
      post organization_projects_path(@owner.organization.slug), params: {
        project: {
          name: "Storefront",
          slug: "Storefront EU",
          description: "Public commerce surface",
          default_locale: "en",
          time_zone: "UTC"
        }
      }
    end
    project = Projects::Project.order(:created_at).last
    assert_redirected_to organization_project_path(@owner.organization.slug, "storefront-eu")

    get organization_projects_path(@owner.organization.slug), params: { q: "storefront" }
    assert_response :success
    assert_select "td", text: /No scan observation yet/
    assert_includes response.body, "Storefront"

    patch organization_project_path(@owner.organization.slug, project.slug), params: {
      project: {
        name: "Storefront Updated",
        description: "Updated project context",
        default_locale: "en",
        time_zone: "UTC"
      }
    }
    assert_redirected_to organization_project_path(@owner.organization.slug, project.slug)
    assert_equal "Storefront Updated", project.reload.name

    patch archive_organization_project_path(@owner.organization.slug, project.slug)
    assert_redirected_to organization_projects_path(@owner.organization.slug)
    assert project.reload.archived?

    get organization_project_path(@owner.organization.slug, project.slug)
    assert_response :success
    assert_select "button", text: "Reactivate project"

    patch reactivate_organization_project_path(@owner.organization.slug, project.slug)
    assert_redirected_to organization_project_path(@owner.organization.slug, project.slug)
    assert project.reload.active?
  end

  test "invalid create rerenders bounded form errors without persisting a scope" do
    assert_no_difference([ "Projects::Project.count", "Authorization::ScopeReference.count" ]) do
      post organization_projects_path(@owner.organization.slug), params: {
        project: {
          name: "X",
          slug: "?",
          description: "a" * 2001,
          default_locale: "en",
          time_zone: "UTC"
        }
      }
    end
    assert_response :unprocessable_content
    assert_select "[role='alert']"
    assert_select "textarea[name='project[description]']"
  end

  test "index and detail never expose another tenant project" do
    own = create_project_for(@owner, name: "Visible Alpha", slug: "visible-alpha")
    foreign = create_organization_for(name: "Foreign Workspace", slug: "foreign-project-workspace")
    enable_project_limit(foreign)
    foreign_project = create_project_for(foreign, name: "Hidden Customer Project", slug: "hidden-project")

    get organization_projects_path(@owner.organization.slug)
    assert_response :success
    assert_includes response.body, own.name
    refute_includes response.body, foreign_project.name

    get organization_project_path(@owner.organization.slug, foreign_project.slug)
    assert_response :forbidden
    refute_includes response.body, foreign_project.name
    refute_includes response.body, foreign.organization.name
  end

  test "project-scoped read lists only the assigned active project" do
    visible = create_project_for(@owner, name: "Assigned Project", slug: "assigned-project")
    hidden = create_project_for(@owner, name: "Unassigned Project", slug: "unassigned-project")
    member = add_member("Scoped Viewer")
    assign_role(member: member, role_key: "viewer", scope_type: "Project", scope_id: visible.id)

    reset!
    authenticate_request(issue_identity_session(user: member.user))
    get organization_projects_path(@owner.organization.slug)

    assert_response :success
    assert_includes response.body, visible.name
    refute_includes response.body, hidden.name
    assert_select "a", text: "Create project", count: 0
  end

  test "archive and reactivate enforce project and organization role scope" do
    project = create_project_for(@owner, slug: "scoped-lifecycle")
    lead = add_member("Scoped SEO Lead")
    assign_role(member: lead, role_key: "seo_lead", scope_type: "Project", scope_id: project.id)

    reset!
    authenticate_request(issue_identity_session(user: lead.user))
    patch archive_organization_project_path(@owner.organization.slug, project.slug)
    assert_response :see_other
    assert project.reload.archived?

    patch reactivate_organization_project_path(@owner.organization.slug, project.slug)
    assert_response :forbidden
    assert project.reload.archived?

    reset!
    authenticate_request(@issued)
    assign_role(member: lead, role_key: "seo_lead", scope_type: "Organization",
      scope_id: @owner.organization.id)
    reset!
    authenticate_request(issue_identity_session(user: lead.user))
    patch reactivate_organization_project_path(@owner.organization.slug, project.slug)
    assert_response :see_other
    assert project.reload.active?
  end

  test "delete permission and recent authentication produce pending deletion without physical removal" do
    project = create_project_for(@owner, slug: "retained-project")

    assert_no_difference("Projects::Project.count") do
      delete organization_project_path(@owner.organization.slug, project.slug),
        params: { confirmation: project.slug }
    end
    assert_redirected_to organization_project_path(@owner.organization.slug, project.slug)
    assert project.reload.pending_deletion?
    assert Auditing::AuditEvent.exists?(action: "project.deletion_requested", target_id: project.id)
    assert Administration::DeletionWorkflow.exists?(target_id: project.id, state: "holding")
  end

  test "deletion request requires a recent session at the lifecycle boundary" do
    project = create_project_for(@owner, slug: "recent-auth-project")
    reset!
    authenticate_request(issue_identity_session(user: @user, at: 30.minutes.ago))

    delete organization_project_path(@owner.organization.slug, project.slug),
      params: { confirmation: project.slug }

    assert_response :unauthorized
    assert project.reload.active?
  end

  test "deletion review warns about exports and requires the exact project slug" do
    project = create_project_for(@owner, slug: "confirm-project")

    get deletion_organization_project_path(@owner.organization.slug, project.slug)
    assert_response :success
    assert_includes response.body, "Archive or export anything you need first"
    assert_includes response.body, "retention hold"

    assert_no_difference("Administration::DeletionWorkflow.count") do
      delete organization_project_path(@owner.organization.slug, project.slug),
        params: { confirmation: "wrong-project" }
    end
    assert_response :unprocessable_content
    assert project.reload.active?
  end

  test "search and pagination are bounded and retain the query" do
    26.times { |index| create_project_for(@owner, name: "Paged #{index.to_s.rjust(2, '0')}", slug: "paged-#{index}") }

    get organization_projects_path(@owner.organization.slug), params: { q: "Paged", page: 2 }
    assert_response :success
    assert_select "nav[aria-label='Project pages'] [aria-current='page']", text: "2"
    assert_select "input[name='q'][value='Paged']"
  end

  test "project dashboard exposes honest empty observations and stable Turbo targets" do
    project = create_project_for(@owner, slug: "empty-dashboard")

    get organization_project_path(@owner.organization.slug, project.slug)

    assert_response :success
    assert_select "h2", text: "Baseline readiness"
    assert_select "turbo-frame#project_scan_status_empty-dashboard [data-observation-state='no_data']"
    assert_select "turbo-frame#project_findings_status_empty-dashboard [data-observation-state='no_data']"
    assert_select "button[disabled][aria-disabled='true']", text: "Run baseline scan"
    assert_select "[data-readiness-state='action_required']", minimum: 1
    assert_includes response.body, "Recent project activity"
    assert_includes response.body, "Project created"
  end

  test "ready dashboard links exact property environment and verification without fake scan metrics" do
    enable_property_limits(@owner, website: 40, mobile: 40)
    set_onboarding_entitlement(@owner, "crawl.manual", true, at: Time.current)
    set_onboarding_entitlement(@owner, "crawl.credits_monthly", 500, at: Time.current)
    project = create_project_for(@owner, slug: "ready-dashboard")
    property = create_property_for(
      @owner,
      project: project,
      display_name: "Ready Website",
      configuration: { origin: "https://ready-dashboard.example.com" }
    )
    environment = property.environments.sole
    property.update!(verification_status: "verified", verified_at: Time.current)

    get organization_project_path(@owner.organization.slug, project.slug)

    assert_response :success
    assert_select "[data-readiness-state='ready']", count: 6
    assert_select "a[href=?]", organization_project_property_path(
      @owner.organization.slug, project.slug, property.id
    ), text: "Ready Website"
    assert_select "a[href=?]", organization_project_property_environment_path(
      @owner.organization.slug, project.slug, property.id, environment.id
    ), text: "Production"
    assert_select "button[disabled]", text: "Run baseline scan"
    assert_includes response.body, "does not enqueue placeholder work"
  end

  test "restricted project reader receives explanations without organization usage or integration data" do
    project = create_project_for(@owner, slug: "restricted-dashboard")
    member = add_member("Restricted Dashboard Viewer")
    assign_role(member: member, role_key: "viewer", scope_type: "Project", scope_id: project.id)
    reset!
    authenticate_request(issue_identity_session(user: member.user))

    get organization_project_path(@owner.organization.slug, project.slug)

    assert_response :success
    assert_select "h2", text: "Crawl usage"
    assert_select "p", text: "Restricted", minimum: 2
    assert_includes response.body, "does not include permission to run scans"
    assert_select "a", text: "Edit project", count: 0
    assert_select "a", text: "Request deletion", count: 0
  end

  private

  def add_member(name)
    Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: name)
    )
  end

  def assign_role(member:, role_key:, scope_type:, scope_id:)
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: member.id,
      role_id: Authorization::Role.find_by!(system: true, key: role_key).id,
      scope_type: scope_type,
      scope_id: scope_id
    )
  end
end
