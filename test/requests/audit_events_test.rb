# frozen_string_literal: true

require "test_helper"

class AuditEventsRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @owner_user = create_identity_user(display_name: "Audit Owner")
    @owner = create_organization_for(
      user: @owner_user,
      name: "Audit Workspace",
      slug: "audit-workspace"
    )
    authenticate_request(issue_identity_session(user: @owner_user))
  end

  test "authorized audit list is tenant scoped filterable and correlated" do
    patch organization_settings_path(@owner.organization.slug), params: {
      organization: {
        name: "Renamed Audit Workspace",
        slug: @owner.organization.slug,
        default_locale: "en",
        time_zone: "UTC"
      }
    }
    assert_response :see_other
    event = Auditing::AuditEvent.find_by!(
      organization_id: @owner.organization.id,
      action: "organization.renamed"
    )
    assert_predicate event.request_id, :present?
    assert_predicate event.trace_id, :present?

    foreign = create_organization_for(name: "Foreign Audit", slug: "foreign-audit-list")
    get organization_audit_events_path(@owner.organization.slug), params: {
      filter: { action: "organization.renamed", result: "succeeded" }
    }

    assert_response :success
    assert_select "h1", text: "Audit log"
    assert_includes response.body, "organization.renamed"
    refute_includes response.body, foreign.organization.id
    assert_select "[aria-disabled='true']", text: "Export CSV"
  end

  test "foreign tenant and member without audit permission cannot list or export" do
    foreign = create_organization_for(name: "Foreign Private Audit", slug: "foreign-private-audit")

    get organization_audit_events_path(foreign.organization.slug)
    assert_response :forbidden
    refute_includes response.body, "organization.created"

    get organization_audit_export_path(foreign.organization.slug)
    assert_response :forbidden

    member_user = create_identity_user(display_name: "No Audit Permission")
    Tenancy::Public.create_membership(actor_membership: @owner.membership, user: member_user)
    reset!
    authenticate_request(issue_identity_session(user: member_user))
    get organization_audit_events_path(@owner.organization.slug)
    assert_response :forbidden
  end

  test "export stays fail closed until the entitlement is implemented" do
    get organization_audit_export_path(@owner.organization.slug)

    assert_response :forbidden
    assert_equal "entitlement_required", response.headers.fetch("X-SearchOps-Error-Code")
    assert_includes response.body, "not enabled"
  end

  test "organization administrator may read but may not export" do
    administrator_user = create_identity_user(display_name: "Audit Administrator")
    administrator = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: administrator_user
    )
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: administrator.id,
      role_id: Authorization::Role.find_by!(key: "organization_admin").id,
      scope_type: "Organization",
      scope_id: @owner.organization.id
    )
    reset!
    authenticate_request(issue_identity_session(user: administrator_user))

    get organization_audit_events_path(@owner.organization.slug)
    assert_response :success
    get organization_audit_export_path(@owner.organization.slug)
    assert_response :forbidden
  end
end
