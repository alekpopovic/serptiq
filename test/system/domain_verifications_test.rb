# frozen_string_literal: true

require "application_system_test_case"

class DomainVerificationsTest < ApplicationSystemTestCase
  setup do
    Authorization::Public.sync_catalog
    @user = create_identity_user(display_name: "Verification System Owner")
    @owner = create_organization_for(user: @user, slug: "verification-system")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "verification-system-project")
    @property = create_property_for(@owner, project: @project)
    @environment = @property.environments.sole
    authenticate_system_browser(issue_identity_session(user: @user))
  end

  test "owner chooses a method and receives exact revocable instructions" do
    visit organization_project_property_environment_path(
      @owner.organization.slug, @project.slug, @property.id, @environment.id
    )
    click_on "Verify ownership"
    assert_text "PROOF OF CONTROL"

    select "HTML meta tag", from: "Method"
    click_on "Issue challenge"

    assert_text "Current instructions"
    assert_text "searchops-verification="
    assert_text "Pending"
    assert_button "Retry verification"
    assert_button "Revoke verification"
  end
end
