# frozen_string_literal: true

require "application_system_test_case"

class PlanCatalogAdminSystemTest < ApplicationSystemTestCase
  test "platform operator reviews and publishes an immutable catalog version" do
    Plans::Public.sync_catalog
    user = create_identity_user(display_name: "Plan Catalog Operator")
    Plans::CatalogAccessGrant.create!(
      user_id: user.id,
      permission: "plan_catalog.publish",
      granted_at: Time.current
    )
    authenticate_system_browser(issue_identity_session(user: user))

    visit admin_plan_catalog_path

    assert_text "Plan catalog"
    assert_text "Enterprise"
    within find("tr", text: "growth") do
      fill_in "publish_confirmation_growth_1", with: "PUBLISH growth VERSION 1 AFTER 0"
      click_button "Publish"
    end

    assert_current_path admin_plan_catalog_path
    assert_text "Plan version published."
    assert_equal "published",
      Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "growth" }, version: 1).status
  end
end
