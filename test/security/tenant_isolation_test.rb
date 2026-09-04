# frozen_string_literal: true

require "test_helper"

class TenantIsolationSecurityTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @owner_user = create_identity_user
    @owner = create_organization_for(user: @owner_user, slug: "security-isolation-owner")
    @foreign = create_organization_for(slug: "security-isolation-foreign")
    authenticate_request(issue_identity_session(user: @owner_user))
  end

  test "organization audit routes reject a real foreign tenant identifier" do
    get organization_audit_events_path(@foreign.organization.slug)
    assert_response :forbidden

    get organization_audit_export_path(@foreign.organization.slug)
    assert_response :forbidden
  end

  test "audit query proof cannot be replayed for another tenant" do
    proof = Authorization::Public.policy(
      actor_membership: @owner.membership,
      organization: @owner.organization
    ).authorize!(permission_key: "audit_log.read")

    assert_raises(Auditing::AccessDenied) do
      Auditing::Public.audit_page(
        organization_id: @foreign.organization.id,
        authorization: proof
      )
    end
  end
end
