# frozen_string_literal: true

require "application_system_test_case"

class TeamManagementSystemTest < ApplicationSystemTestCase
  test "owner creates renames populates and archives a team" do
    user = create_identity_user
    owner = create_organization_for(user: user, name: "System Team Org", slug: "system-team-org")
    Tenancy::Public.create_membership(
      actor_membership: owner.membership,
      user: create_identity_user(display_name: "System Team Member")
    )
    authenticate_system_browser(issue_identity_session(user: user))

    visit organization_teams_path(owner.organization.slug)
    click_link "Create team"
    fill_in "Team name", with: "Search Team"
    click_button "Create team"
    assert_text "Team created"

    fill_in "Search organization members", with: "System Team Member"
    click_button "Search"
    select "System Team Member", from: "Member"
    click_button "Add member"
    assert_text "Member added to team"
    assert_text "System Team Member"

    fill_in "Team name", with: "Discovery Team"
    click_button "Save team name"
    assert_text "Team renamed"
    assert_text "Discovery Team"

    accept_confirm { click_button "Archive team" }
    assert_text "Team archived"
    assert_text "Archived teams are read-only"
    assert_no_button "Add member"
  end
end
