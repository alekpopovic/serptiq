# frozen_string_literal: true

require "test_helper"

class ScansRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @user = create_identity_user(display_name: "Scan Owner")
    @owner = create_organization_for(user: @user, slug: "scan-workspace")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "scan-project")
    @property = create_property_for(@owner, project: @project)
    @scan = create_scan_for(@owner, project: @project, property: @property)
    authenticate_request(issue_identity_session(user: @user))
  end

  test "authorized project scan list and detail expose bounded aggregate observations" do
    get organization_project_scans_path(@owner.organization.slug, @project.slug)

    assert_response :success
    assert_select "h1", text: "Scans"
    assert_includes response.body, @scan.id
    assert_includes response.body, "Requested"
    refute_includes response.body, "solid_queue"

    get organization_project_scan_path(@owner.organization.slug, @project.slug, @scan.id)

    assert_response :success
    assert_select "div#scan_progress_#{@scan.id}[aria-live='polite']"
    assert_select "h2", text: "Immutable provenance"
    assert_select "button", text: "Request cancellation"
    assert_includes response.body, "Individual failures"
  end

  test "cancel action records immediate cancellation and cannot reopen the terminal scan" do
    assert_difference("Crawling::ScanEvent.count", 1) do
      patch cancel_organization_project_scan_path(
        @owner.organization.slug, @project.slug, @scan.id
      )
    end

    assert_redirected_to organization_project_scan_path(
      @owner.organization.slug, @project.slug, @scan.id
    )
    assert_equal "canceled", @scan.reload.status

    get organization_project_scan_path(@owner.organization.slug, @project.slug, @scan.id)
    assert_response :success
    assert_select "button", text: "Request cancellation", count: 0
  end

  test "nested scan substitution and another tenant project fail closed without leaking scan data" do
    sibling = create_project_for(@owner, slug: "scan-project-sibling")
    get organization_project_scan_path(@owner.organization.slug, sibling.slug, @scan.id)
    assert_response :forbidden
    refute_includes response.body, @scan.settings_digest

    foreign = create_organization_for(slug: "scan-workspace-foreign")
    enable_project_limit(foreign)
    foreign_project = create_project_for(foreign, slug: "scan-project-foreign")
    get organization_project_scans_path(@owner.organization.slug, foreign_project.slug)
    assert_response :forbidden
    refute_includes response.body, foreign_project.name
  end

  test "project viewer can read scans but cannot see or invoke cancellation" do
    viewer_user = create_identity_user(display_name: "Scan Viewer")
    viewer = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: viewer_user
    )
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: viewer.id,
      role_id: Authorization::Role.find_by!(system: true, key: "viewer").id,
      scope_type: "Project",
      scope_id: @project.id
    )
    reset!
    authenticate_request(issue_identity_session(user: viewer_user))

    get organization_project_scan_path(@owner.organization.slug, @project.slug, @scan.id)
    assert_response :success
    assert_select "button", text: "Request cancellation", count: 0

    patch cancel_organization_project_scan_path(
      @owner.organization.slug, @project.slug, @scan.id
    )
    assert_response :forbidden
    assert_equal "requested", @scan.reload.status
  end
end
