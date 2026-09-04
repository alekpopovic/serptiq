# frozen_string_literal: true

require "application_system_test_case"

class OrganizationFlowsSystemTest < ApplicationSystemTestCase
  test "creates an organization through the no-JavaScript-compatible form" do
    authenticate_system_browser(issue_identity_session)

    visit onboarding_path
    click_link "Set up organization"
    fill_in "Organization name", with: "North Star Studio"
    fill_in "Organization slug", with: "North Star Studio"
    click_button "Create organization"

    assert_current_path organization_dashboard_path("north-star-studio")
    assert_text "Verified organization: North Star Studio"
    assert_link "Create project"
  end

  test "switches between only the user's active organizations" do
    user = create_identity_user
    alpha = create_organization_for(user: user, name: "Alpha Workspace", slug: "alpha-workspace")
    create_organization_for(user: user, name: "Beta Workspace", slug: "beta-workspace")
    create_organization_for(name: "Foreign Secret", slug: "foreign-secret")
    authenticate_system_browser(issue_identity_session(user: user))

    visit organization_dashboard_path(alpha.organization.slug)
    find("summary[aria-label='Choose organization']").click
    click_link "Beta Workspace"

    assert_current_path organization_dashboard_path("beta-workspace")
    assert_text "Verified organization: Beta Workspace"
    assert_no_text "Foreign Secret"
  end

  test "owner renames an organization and the prior slug redirects to the canonical path" do
    user = create_identity_user
    result = create_organization_for(user: user, name: "Old Name", slug: "old-name")
    authenticate_system_browser(issue_identity_session(user: user))

    visit organization_settings_path(result.organization.slug)
    fill_in "Organization name", with: "New Name"
    fill_in "Organization slug", with: "new-name"
    click_button "Save organization settings"

    assert_current_path organization_settings_path("new-name")
    assert_text "Organization settings were updated"
    visit organization_dashboard_path("old-name")
    assert_current_path organization_dashboard_path("new-name")
    assert_text "Verified organization: New Name"
  end

  test "an inaccessible real slug renders the generic denial without foreign data" do
    user = create_identity_user
    create_organization_for(user: user, slug: "my-accessible-org")
    foreign = create_organization_for(name: "Hidden Customer Name", slug: "hidden-customer")
    authenticate_system_browser(issue_identity_session(user: user))

    visit organization_dashboard_path(foreign.organization.slug)

    assert_text "You do not have permission to perform this action"
    assert_no_text "Hidden Customer Name"
  end
end
