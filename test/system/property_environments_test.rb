# frozen_string_literal: true

require "application_system_test_case"

class PropertyEnvironmentsSystemTest < ApplicationSystemTestCase
  test "manages a public IDNA staging environment" do
    user = create_identity_user(display_name: "Environment System Owner")
    owner = create_organization_for(user: user, slug: "system-environments")
    enable_project_limit(owner)
    enable_property_limits(owner)
    project = create_project_for(owner, slug: "system-environment-project")
    property = create_property_for(owner, project: project)
    authenticate_system_browser(issue_identity_session(user: user))

    visit organization_project_property_path(owner.organization.slug, project.slug, property.id)
    click_link "Manage environments"
    assert_text "exactly one primary production origin"
    assert_text "Primary"
    click_link "Add environment"
    assert_text "Public targets only"
    fill_in "Display name", with: "European staging"
    fill_in "Stable key", with: "staging-eu"
    select "Staging", from: "Environment kind"
    fill_in "HTTP(S) origin", with: "https://BÜCHER.example./"
    click_button "Create environment"

    assert_text "Environment created"
    assert_text "European staging"
    assert_text "https://xn--bcher-kva.example"
    assert_text "https://bücher.example"
    assert_text "not a network-safety guarantee"
  end
end
