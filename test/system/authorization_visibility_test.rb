# frozen_string_literal: true

require "application_system_test_case"

class AuthorizationVisibilitySystemTest < ApplicationSystemTestCase
  test "read-only member sees settings without mutation controls" do
    Authorization::Public.sync_catalog
    owner_user = create_identity_user
    owner = create_organization_for(user: owner_user, name: "Visible Read Only", slug: "visible-read-only")
    analyst_user = create_identity_user(display_name: "Read Only Browser User")
    analyst = Tenancy::Public.create_membership(actor_membership: owner.membership, user: analyst_user)
    Authorization::Public.assign_role(
      actor_membership: owner.membership,
      grantee_type: "Membership",
      grantee_id: analyst.id,
      role_id: Authorization::Role.find_by!(key: "analyst").id,
      scope_type: "Organization",
      scope_id: owner.organization.id
    )
    authenticate_system_browser(issue_identity_session(user: analyst_user))

    visit organization_settings_path(owner.organization.slug)

    assert_text "General details"
    assert_text "you do not have permission to change them"
    assert_no_field "Organization name"
    assert_no_button "Save organization settings"
  end

  test "client viewer sees only one assigned project and no organization administration" do
    owner_user = create_identity_user(display_name: "Scoped Browser Owner")
    owner = create_organization_for(
      user: owner_user, name: "Scoped Browser Workspace", slug: "scoped-browser-workspace"
    )
    enable_project_limit(owner, limit: 5)
    enable_property_limits(owner, website: 5, mobile: 5)
    visible_project = create_project_for(
      owner, name: "Visible Client Project", slug: "visible-client-project"
    )
    hidden_project = create_project_for(
      owner, name: "Hidden Internal Project", slug: "hidden-internal-project"
    )
    visible_property = create_property_for(
      owner, project: visible_project, display_name: "Visible Client Website"
    )
    hidden_property = create_property_for(
      owner, project: hidden_project, display_name: "Hidden Internal Website"
    )
    viewer_user = create_identity_user(display_name: "Restricted Client Viewer")
    viewer = Tenancy::Public.create_membership(
      actor_membership: owner.membership, user: viewer_user
    )
    Authorization::Public.assign_role(
      actor_membership: owner.membership,
      grantee_type: "Membership",
      grantee_id: viewer.id,
      role_id: Authorization::Role.find_by!(system: true, key: "viewer").id,
      scope_type: "Project",
      scope_id: visible_project.id
    )
    authenticate_system_browser(issue_identity_session(user: viewer_user))

    visit organization_projects_path(owner.organization.slug)

    assert_text visible_project.name
    assert_no_text hidden_project.name
    assert_no_link "Members"
    assert_no_link "Invitations"
    assert_no_link "Teams"
    assert_no_link "Plans"
    assert_no_link "Usage"
    assert_no_link "Organization settings"

    click_link "View"
    assert_text visible_project.name
    assert_no_link "Edit project"
    assert_no_button "Archive project"
    assert_no_button "Request deletion"
    click_link "View properties"
    assert_text visible_property.display_name
    assert_no_text hidden_property.display_name
    assert_no_link "Add property"

    visit organization_project_path(owner.organization.slug, hidden_project.slug)
    assert_text "You do not have permission to perform this action"
    assert_no_text hidden_project.name
  end
end
