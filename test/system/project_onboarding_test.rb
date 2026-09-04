# frozen_string_literal: true

require "application_system_test_case"

class ProjectOnboardingSystemTest < ApplicationSystemTestCase
  setup do
    @user = create_identity_user(display_name: "Guided System Owner")
    @owner = create_organization_for(user: @user, slug: "guided-system")
    enable_onboarding_entitlements(@owner)
    authenticate_system_browser(issue_identity_session(user: @user))
  end

  test "website setup reaches a factual pending-verification checklist" do
    start_and_complete_project_step("Website Guided", "website-guided")
    click_button "Save and continue"
    fill_in "Website display name", with: "Marketing Website"
    fill_in "Production origin", with: "https://www.example.com"
    click_button "Save and continue"
    choose "onboarding_verification_method_dns_txt"
    click_button "Save and continue"
    fill_in "Maximum URLs", with: "250"
    fill_in "Maximum crawl depth", with: "4"
    click_button "Save and continue"

    assert_text "Review saved values"
    assert_text "creates no scan and reserves no credits"
    click_button "Create project and properties"

    assert_text "Factual readiness checklist"
    assert_text "Project exists"
    assert_text "Origin normalized"
    assert_text "Ownership verified"
    assert_text "Not ready"
    assert_text "reserved zero scan credits"
    assert_equal 0, Usage::QuotaReservation.count
  end

  test "combined setup creates Android and iOS additions" do
    start_and_complete_project_step("Combined Guided", "combined-guided-system")
    find("#onboarding_flow_type_combined").choose
    find("#onboarding_add_android").check
    find("#onboarding_add_ios").check
    click_button "Save and continue"
    fill_in "Website display name", with: "Combined Website"
    fill_in "Production origin", with: "https://combined.example.com"
    fill_in "Android display name", with: "Combined Android"
    fill_in "Android package name", with: "com.example.combined"
    fill_in "iOS display name", with: "Combined iOS"
    fill_in "iOS bundle ID", with: "com.example.combined"
    fill_in "Apple Team ID", with: "A1B2C3D4E5"
    click_button "Save and continue"
    click_button "Save and continue"
    click_button "Save and continue"
    click_button "Create project and properties"

    assert_text "Project setup status"
    project = Projects::Project.find_by!(slug: "combined-guided-system")
    assert_equal %w[android_app ios_app website], Properties::Property.where(project_id: project.id).order(:kind).pluck(:kind)
  end

  test "saved setup resumes at the exact server-owned step" do
    start_and_complete_project_step("Resume Guided", "resume-guided")

    visit organization_project_onboarding_path(@owner.organization.slug)
    assert_text "A saved setup is in progress"
    assert_text "Resume at product"
    click_link "Resume setup"

    assert_text "Product"
    assert_selector "li[aria-current='step']", text: "2. Product"
    click_button "Back"
    assert_text "Project"
    assert_field "Project name", with: "Resume Guided"
  end

  test "server validation failure is accessible and retains the current step" do
    visit organization_project_onboarding_path(@owner.organization.slug)
    click_button "Start guided setup"
    fill_in "Project name", with: "X"
    fill_in "Project slug", with: "?"
    click_button "Save and continue"

    assert_text "Review the highlighted setup values"
    assert_selector "[role='alert'][tabindex='-1']"
    assert_selector "li[aria-current='step']", text: "1. Project"
    assert_equal "onboarding-errors", page.evaluate_script("document.activeElement.id")
    assert_equal 0, Projects::Project.count
  end

  private

  def start_and_complete_project_step(name, slug)
    visit organization_project_onboarding_path(@owner.organization.slug)
    click_button "Start guided setup"
    fill_in "Project name", with: name
    fill_in "Project slug", with: slug
    fill_in "Description", with: "System onboarding"
    select "en", from: "Default locale"
    select "UTC", from: "Time zone"
    click_button "Save and continue"
  end
end
