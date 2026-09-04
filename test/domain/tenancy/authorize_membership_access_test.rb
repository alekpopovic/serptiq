# frozen_string_literal: true

require "test_helper"

class AuthorizeMembershipAccessTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "domain-access-proof")
    @member = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user
    )
  end

  test "accepts only an allowed decision bound to the actor organization scope and permission" do
    decision = Authorization::Public.policy(
      actor_membership: @owner.membership,
      organization: @owner.organization
    ).decision(permission_key: "teams.manage")

    team = Tenancy::Public.create_team(
      actor_membership: @owner.membership,
      authorization: decision,
      name: "Authorized Domain Team"
    )
    assert_equal @owner.organization.id, team.organization_id

    assert_raises(Tenancy::OrganizationAccessDenied) do
      Tenancy::Public.create_team(
        actor_membership: @member,
        authorization: decision,
        name: "Stolen Decision Team"
      )
    end
  end
end
