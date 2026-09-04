# frozen_string_literal: true

require "application_system_test_case"

class AuthorizationVisibilitySystemTest < ApplicationSystemTestCase
  test "read-only member sees settings without mutation controls" do
    Authorization::Public.sync_catalog
    owner_user = create_identity_user
    owner = create_organization_for(user: owner_user, name: "Visible Read Only", slug: "visible-read-only")
    analyst_user = create_identity_user(display_name: "Read Only Browser User")
    analyst = Tenancy::Public.create_membership(actor_membership: owner.membership, user: analyst_user)
    Authorization::Public.assign_role(
      actor_membership: owner.membership,
      grantee_type: "Membership",
      grantee_id: analyst.id,
      role_id: Authorization::Role.find_by!(key: "analyst").id,
      scope_type: "Organization",
      scope_id: owner.organization.id
    )
    authenticate_system_browser(issue_identity_session(user: analyst_user))

    visit organization_settings_path(owner.organization.slug)

    assert_text "General details"
    assert_text "you do not have permission to change them"
    assert_no_field "Organization name"
    assert_no_button "Save organization settings"
  end
end
