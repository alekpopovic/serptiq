# frozen_string_literal: true

require "test_helper"

class EntitlementsOverrideIsolationTest < ActiveSupport::TestCase
  setup do
    Plans::Public.sync_catalog
    Entitlements::Public.sync_catalog
    @operator = create_identity_user(display_name: "Override Operator")
    Plans::CatalogAccessGrant.create!(
      user_id: @operator.id, permission: "plan_catalog.publish", granted_at: Time.current
    )
    @authorization = Plans::Public.authorize_catalog!(
      user: @operator, permission: "plan_catalog.publish"
    )
    @owned = create_organization_for(user: @operator, name: "Owned Override", slug: "owned-override")
    @foreign = create_organization_for(name: "Foreign Override", slug: "foreign-override")
  end

  test "platform authority is also bound to an active membership in the target organization" do
    error = assert_raises(Entitlements::AccessDenied) do
      set_override(organization_id: @foreign.organization.id, actor: @owned.membership)
    end

    assert_equal "entitlement_override_platform_authority_required", error.reason_code
    refute Entitlements::OrganizationOverride.exists?(organization_id: @foreign.organization.id)
  end

  test "an organization RBAC decision including a custom role cannot change entitlements" do
    rbac_decision = Authorization::DecisionResult.new(
      allowed: true,
      reason_code: "permission_granted",
      permission_key: "billing.manage",
      actor_membership_id: @owned.membership.id,
      organization_id: @owned.organization.id,
      scope_type: "Organization",
      scope_id: @owned.organization.id,
      sources: [ SecureRandom.uuid ]
    )

    assert_raises(Entitlements::AccessDenied) do
      Entitlements::Public.set_organization_override(
        organization_id: @owned.organization.id,
        entitlement_key: "reports.pdf",
        value: true,
        reason: "Attempted RBAC elevation",
        source: "support",
        actor_membership: @owned.membership,
        authorization: rbac_decision
      )
    end
  end

  test "composite foreign key rejects cross-organization creator attribution" do
    definition = Entitlements::Definition.find_by!(key: "reports.pdf")

    assert_raises(ActiveRecord::InvalidForeignKey) do
      Entitlements::OrganizationOverride.transaction(requires_new: true) do
        Entitlements::OrganizationOverride.insert_all!([ {
          organization_id: @foreign.organization.id,
          entitlement_definition_id: definition.id,
          value_type: "boolean",
          value: true,
          starts_at: Time.current,
          reason: "Cross tenant creator",
          source: "support",
          created_by_membership_id: @owned.membership.id,
          created_at: Time.current,
          updated_at: Time.current
        } ])
      end
    end
  end

  test "subscription projection cannot bind a foreign organization to another tenant subscription" do
    version = publish_catalog_version(plan_key: "free", version: 1, authorization: @authorization)
    subscription = Billing::Public.create_subscription_reference(
      organization_id: @owned.organization.id,
      plan_version_id: version.id,
      billing_interval: "monthly"
    )

    error = assert_raises(Entitlements::CatalogConflict) do
      Entitlements::Public.bind_subscription(
        organization_id: @foreign.organization.id,
        subscription_id: subscription.id,
        plan_version_id: version.id,
        subscription_revision: subscription.lock_version
      )
    end

    assert_equal "entitlement_subscription_context_invalid", error.reason_code
    refute Entitlements::SubscriptionContext.active.exists?(organization_id: @foreign.organization.id)
  end

  test "override rows reject rewrites and deletion but allow one attributed revocation" do
    override = set_override(organization_id: @owned.organization.id, actor: @owned.membership)

    assert_raises(ActiveRecord::StatementInvalid) do
      Entitlements::OrganizationOverride.transaction(requires_new: true) do
        Entitlements::OrganizationOverride.where(id: override.id).update_all(reason: "Rewritten reason")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Entitlements::OrganizationOverride.transaction(requires_new: true) do
        Entitlements::OrganizationOverride.where(id: override.id).delete_all
      end
    end

    revoked = Entitlements::Public.revoke_organization_override(
      organization_id: @owned.organization.id,
      override_id: override.id,
      actor_membership: @owned.membership,
      authorization: @authorization
    )
    assert_predicate revoked, :revoked_at?
    assert_equal @owned.membership.id, revoked.revoked_by_membership_id
    assert Auditing::AuditEvent.exists?(action: "entitlement.override_revoked", target_id: override.id)
  end

  private

  def set_override(organization_id:, actor:)
    Entitlements::Public.set_organization_override(
      organization_id: organization_id,
      entitlement_key: "reports.pdf",
      value: true,
      reason: "Approved support override",
      source: "support",
      actor_membership: actor,
      authorization: @authorization
    )
  end
end
