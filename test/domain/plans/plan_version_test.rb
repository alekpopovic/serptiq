# frozen_string_literal: true

require "test_helper"

class PlansPlanVersionTest < ActiveSupport::TestCase
  setup do
    Plans::Public.sync_catalog
    @user = create_identity_user(display_name: "Catalog Publisher")
    Plans::CatalogAccessGrant.create!(
      user_id: @user.id,
      permission: "plan_catalog.publish",
      granted_at: Time.current
    )
    @authorization = Plans::Public.authorize_catalog!(
      user: @user,
      permission: "plan_catalog.publish"
    )
    @version = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "growth" }, version: 1)
  end

  test "controlled publish and retire transitions are audited" do
    published = Plans::Public.publish_version(
      plan_key: "growth",
      version: 1,
      effective_at: Time.current,
      confirmation: "PUBLISH growth VERSION 1",
      authorization: @authorization
    )
    assert_equal "published", published.status
    assert Auditing::AuditEvent.exists?(
      actor_user_id: @user.id,
      action: "plan.version_published",
      target_id: published.id,
      result: "succeeded"
    )

    retired = Plans::Public.retire_version(
      plan_key: "growth",
      version: 1,
      confirmation: "RETIRE growth VERSION 1",
      authorization: @authorization
    )
    assert_equal "retired", retired.status
    assert Auditing::AuditEvent.exists?(
      actor_user_id: @user.id,
      action: "plan.version_retired",
      target_id: retired.id,
      result: "succeeded"
    )
  end

  test "confirmation failure records a denied audit event without publishing" do
    error = assert_raises(Plans::CatalogTransitionInvalid) do
      Plans::Public.publish_version(
        plan_key: "growth",
        version: 1,
        effective_at: Time.current,
        confirmation: "publish it",
        authorization: @authorization
      )
    end

    assert_equal "plan_publish_confirmation_invalid", error.reason_code
    assert_equal "draft", @version.reload.status
    assert Auditing::AuditEvent.exists?(
      actor_user_id: @user.id,
      action: "plan.version_publish_rejected",
      target_id: @version.id,
      result: "denied"
    )
  end

  test "read-only catalog authorization cannot publish" do
    reader = create_identity_user(display_name: "Catalog Reader")
    Plans::CatalogAccessGrant.create!(
      user_id: reader.id,
      permission: "plan_catalog.read",
      granted_at: Time.current
    )
    decision = Plans::Public.authorize_catalog!(user: reader, permission: "plan_catalog.read")

    assert_raises(Plans::CatalogAccessDenied) do
      Plans::Public.publish_version(
        plan_key: "growth",
        version: 1,
        effective_at: Time.current,
        confirmation: "PUBLISH growth VERSION 1",
        authorization: decision
      )
    end
    assert_equal "draft", @version.reload.status
  end

  test "model and PostgreSQL trigger reject mutation or deletion after publish" do
    Plans::Public.publish_version(
      plan_key: "growth",
      version: 1,
      effective_at: Time.current,
      confirmation: "PUBLISH growth VERSION 1",
      authorization: @authorization
    )

    refute @version.reload.update(display_name: "Rewritten Growth")
    assert_includes @version.errors[:base], "published plan versions are immutable"
    assert_raises(ActiveRecord::RecordNotDestroyed) { @version.destroy! }

    assert_raises(ActiveRecord::StatementInvalid) do
      Plans::PlanVersion.transaction(requires_new: true) do
        Plans::PlanVersion.where(id: @version.id).update_all(display_name: "Direct SQL Rewrite")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Plans::PlanVersion.transaction(requires_new: true) do
        Plans::PlanVersion.where(id: @version.id).update_all(effective_at: 1.day.from_now)
      end
    end
    assert_equal "Growth", @version.reload.display_name
  end

  test "database constraints enforce stable keys and unique per-plan versions" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Plans::Plan.transaction(requires_new: true) do
        Plans::Plan.insert_all!([ { key: "unknown", display_order: 1, created_at: Time.current, updated_at: Time.current } ])
      end
    end

    attributes = @version.attributes.except("id", "created_at", "updated_at", "lock_version")
      .merge("created_at" => Time.current, "updated_at" => Time.current)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Plans::PlanVersion.transaction(requires_new: true) { Plans::PlanVersion.insert_all!([ attributes ]) }
    end
  end
end
