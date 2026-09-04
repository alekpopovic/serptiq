# frozen_string_literal: true

require "application_system_test_case"

class AuditEventsSystemTest < ApplicationSystemTestCase
  test "owner opens and filters immutable organization history" do
    Authorization::Public.sync_catalog
    user = create_identity_user(display_name: "Audit Browser Owner")
    owner = create_organization_for(user: user, name: "Browser Audit", slug: "browser-audit")
    authenticate_system_browser(issue_identity_session(user: user))

    visit organization_settings_path(owner.organization.slug)
    click_link "View audit log"

    assert_text "Audit log"
    assert_text "organization.created"
    assert_button "Filter"
    assert_text "Available only after the audit export entitlement ships."
  end
end
