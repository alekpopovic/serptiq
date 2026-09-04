# frozen_string_literal: true

require "application_system_test_case"

class OwnershipTransferSystemTest < ApplicationSystemTestCase
  test "owner confirms transfer and both users receive immediate permission effects" do
    Authorization::Public.sync_catalog
    owner_user = create_identity_user(display_name: "Browser Previous Owner")
    organization = create_organization_for(
      user: owner_user,
      name: "Browser Transfer Org",
      slug: "browser-transfer-org"
    )
    target_user = create_identity_user(display_name: "Browser New Owner")
    target = Tenancy::Public.create_membership(actor_membership: organization.membership, user: target_user)
    target_session = issue_identity_session(user: target_user, at: 1.minute.ago)
    authenticate_system_browser(issue_identity_session(user: owner_user, at: 1.minute.ago))

    visit organization_settings_path(organization.organization.slug)
    click_link "Review ownership transfer"
    select "Browser New Owner", from: "New owner"
    fill_in "Type TRANSFER OWNERSHIP to confirm", with: "TRANSFER OWNERSHIP"
    accept_confirm { click_button "Transfer ownership" }

    assert_current_path dashboard_path
    assert_text "Ownership transferred"
    visit organization_dashboard_path(organization.organization.slug)
    assert_text "You do not have permission to perform this action"
    assert_equal "privilege_changed", target_session.session.reload.revoke_reason

    using_session(:new_owner) do
      authenticate_system_browser(issue_identity_session(user: target_user))
      visit organization_settings_path(organization.organization.slug)
      assert_link "Review ownership transfer"
      assert target.reload.owner?
    end
  end
end
