# frozen_string_literal: true

require "test_helper"

class OrganizationContextRequestTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_identity_user
    @issued = issue_identity_session(user: @user)
    @accessible = create_organization_for(user: @user, name: "Accessible Workspace", slug: "accessible-workspace")
    @foreign = create_organization_for(name: "Private Foreign Workspace", slug: "private-foreign")
    authenticate_request(@issued)
  end

  test "route slug establishes context only after active membership verification" do
    assert_tenant_request_isolated(
      authorized: organization_dashboard_path(@accessible.organization.slug),
      foreign: organization_dashboard_path(@foreign.organization.slug)
    ) do |path|
      get path
    end

    assert_equal "authorization_denied", response.headers.fetch("X-SearchOps-Error-Code")
    refute_includes response.body, @foreign.organization.name
    refute_includes response.body, @foreign.organization.slug
    assert_nil Current.user
    assert_nil Current.organization
    assert_nil Current.membership
  end

  test "accessible context renders verified organization without leaking switcher entries" do
    get organization_dashboard_path(@accessible.organization.slug)

    assert_response :success
    assert_includes response.body, "Accessible Workspace"
    assert_includes response.body, "active membership"
    refute_includes response.body, @foreign.organization.name
    assert_nil Current.organization
    assert_nil Current.membership
  end

  test "suspended membership and unknown slug have the same generic denial" do
    @accessible.membership.update!(status: "suspended", suspended_at: Time.current)

    get organization_dashboard_path(@accessible.organization.slug)
    assert_response :forbidden
    suspended_code = response.headers.fetch("X-SearchOps-Error-Code")
    suspended_title = css_select("h1").sole.text

    get organization_dashboard_path("unknown-workspace")
    assert_response :forbidden
    assert_equal suspended_code, response.headers.fetch("X-SearchOps-Error-Code")
    assert_equal suspended_title, css_select("h1").sole.text
    refute_includes response.body, @accessible.organization.name
  end
end
