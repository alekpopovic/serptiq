# frozen_string_literal: true

require "test_helper"

class PlanCatalogAdminRequestTest < ActionDispatch::IntegrationTest
  setup do
    Plans::Public.sync_catalog
    @user = create_identity_user(display_name: "Platform Catalog Operator")
    @session = issue_identity_session(user: @user)
  end

  test "authentication and platform grant are required independently of organization ownership" do
    get admin_plan_catalog_path
    assert_response :found

    create_organization_for(user: @user, name: "Owner Is Not Platform Admin", slug: "not-platform-admin")
    authenticate_request(@session)
    get admin_plan_catalog_path
    assert_response :forbidden

    post publish_admin_plan_version_path("free", 1), params: { confirmation: "PUBLISH free VERSION 1" }
    assert_response :forbidden
    assert_equal "draft", plan_version("free", 1).status
  end

  test "read grant exposes immutable catalog but not controlled actions" do
    grant("plan_catalog.read")
    authenticate_request(@session)

    get admin_plan_catalog_path
    assert_response :success
    assert_select "h1", text: "Plan catalog"
    assert_select "tbody tr", count: 5
    assert_select "input[value='Publish']", count: 0

    post publish_admin_plan_version_path("starter", 1),
      params: { confirmation: "PUBLISH starter VERSION 1" }
    assert_response :forbidden
  end

  test "publish and retire require exact confirmation and create audit records" do
    grant("plan_catalog.publish")
    authenticate_request(@session)

    post publish_admin_plan_version_path("growth", 1), params: { confirmation: "yes" }
    assert_response :conflict
    assert Auditing::AuditEvent.exists?(
      action: "plan.version_publish_rejected",
      actor_user_id: @user.id,
      result: "denied"
    )

    post publish_admin_plan_version_path("growth", 1),
      params: { confirmation: "PUBLISH growth VERSION 1" }
    assert_response :see_other
    assert_equal "published", plan_version("growth", 1).status
    assert Auditing::AuditEvent.exists?(action: "plan.version_published", actor_user_id: @user.id)

    patch retire_admin_plan_version_path("growth", 1),
      params: { confirmation: "RETIRE growth VERSION 1" }
    assert_response :see_other
    assert_equal "retired", plan_version("growth", 1).status
    assert Auditing::AuditEvent.exists?(action: "plan.version_retired", actor_user_id: @user.id)
  end

  test "controlled mutation requires recent authentication" do
    grant("plan_catalog.publish")
    stale = issue_identity_session(user: @user, at: 20.minutes.ago)
    authenticate_request(stale)

    post publish_admin_plan_version_path("agency", 1),
      params: { confirmation: "PUBLISH agency VERSION 1" }

    assert_response :unauthorized
    assert_equal "draft", plan_version("agency", 1).status
  end

  private

  def grant(permission)
    Plans::CatalogAccessGrant.create!(user_id: @user.id, permission: permission, granted_at: Time.current)
  end

  def plan_version(key, version)
    Plans::PlanVersion.joins(:plan).find_by!(plans: { key: key }, version: version)
  end
end
