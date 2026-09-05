# frozen_string_literal: true

require "application_system_test_case"

class ProjectsSystemTest < ApplicationSystemTestCase
  test "owner completes project create edit archive and reactivate flow" do
    Authorization::Public.sync_catalog
    user = create_identity_user(display_name: "System Project Owner")
    owner = create_organization_for(user: user, name: "System Projects", slug: "system-projects")
    enable_project_limit(owner, limit: 5)
    authenticate_system_browser(issue_identity_session(user: user))

    visit organization_projects_path(owner.organization.slug)
    click_link "Create project"
    fill_in "Project name", with: "Customer Website"
    fill_in "Project slug", with: "Customer Website"
    fill_in "Description", with: "Web and mobile discovery program"
    select "en", from: "Default locale"
    select "UTC", from: "Time zone"
    click_button "Create project"

    assert_current_path organization_project_path(owner.organization.slug, "customer-website")
    assert_text "Project created"
    assert_text "No persisted scan observation exists yet"
    click_link "Edit project"
    fill_in "Project name", with: "Customer Discovery"
    click_button "Save project settings"
    assert_text "Customer Discovery"

    accept_confirm { click_button "Archive project" }
    assert_current_path organization_projects_path(owner.organization.slug)
    click_link "View"
    assert_text "New scans and schedules are disabled"
    click_button "Reactivate project"
    assert_text "Project reactivated"
    assert_text "Customer Discovery"

    click_link "Request deletion"
    assert_text "Archive or export anything you need first"
    fill_in "confirmation", with: "customer-website"
    click_button "Request project deletion"
    assert_text "Project deletion requested"
    assert_text "Retained history remains reviewable"
    click_button "Cancel deletion"
    assert_text "Project deletion canceled"
  end
end
