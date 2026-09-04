# frozen_string_literal: true

require "application_system_test_case"

class PropertiesSystemTest < ApplicationSystemTestCase
  test "creates a website property" do
    owner, project = property_workspace("website")

    visit organization_project_properties_path(owner.organization.slug, project.slug)
    click_link "Add property"
    fill_in "Display name", with: "Marketing Website"
    select "Website", from: "Property type"
    fill_in "Website origin", with: "https://www.example.com"
    click_button "Add property"

    assert_text "Property created"
    assert_text "Marketing Website"
    assert_text "https://www.example.com"
    assert_text "Creating a property does not prove ownership"
  end

  test "creates a web application property" do
    owner, project = property_workspace("web-application")

    visit new_organization_project_property_path(owner.organization.slug, project.slug)
    fill_in "Display name", with: "Customer Portal"
    select "Web application", from: "Property type"
    fill_in "Website origin", with: "https://app.example.com:8443"
    click_button "Add property"

    assert_text "Web application"
    assert_text "https://app.example.com:8443"
  end

  test "creates an Android app property" do
    owner, project = property_workspace("android")

    visit new_organization_project_property_path(owner.organization.slug, project.slug)
    fill_in "Display name", with: "Android App"
    select "Android app", from: "Property type"
    fill_in "Android package name", with: "com.example.mobile"
    click_button "Add property"

    assert_text "Android app"
    assert_text "com.example.mobile"
    assert_text "Unverified"
  end

  test "creates and edits an iOS app property" do
    owner, project = property_workspace("ios")

    visit new_organization_project_property_path(owner.organization.slug, project.slug)
    fill_in "Display name", with: "iOS App"
    select "iOS app", from: "Property type"
    fill_in "iOS bundle ID", with: "com.example.mobile"
    fill_in "Apple Team ID", with: "a1b2c3d4e5"
    click_button "Add property"

    assert_text "A1B2C3D4E5"
    click_link "Edit property"
    fill_in "Display name", with: "iOS Customer App"
    click_button "Save property settings"
    assert_text "iOS Customer App"
  end

  private

  def property_workspace(suffix)
    user = create_identity_user(display_name: "#{suffix.humanize} Property Owner")
    owner = create_organization_for(user: user, slug: "system-property-#{suffix}")
    enable_project_limit(owner)
    enable_property_limits(owner)
    project = create_project_for(owner, slug: "system-property-project-#{suffix}")
    authenticate_system_browser(issue_identity_session(user: user))
    [ owner, project ]
  end
end
