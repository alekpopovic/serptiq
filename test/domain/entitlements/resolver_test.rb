# frozen_string_literal: true

require "test_helper"

class EntitlementsResolverTest < ActiveSupport::TestCase
  setup do
    Current.reset
    Plans::Public.sync_catalog
    Entitlements::Public.sync_catalog
    @publisher = create_identity_user(display_name: "Entitlement Operator")
    Plans::CatalogAccessGrant.create!(
      user_id: @publisher.id, permission: "plan_catalog.publish", granted_at: Time.current
    )
    @platform_authorization = Plans::Public.authorize_catalog!(
      user: @publisher, permission: "plan_catalog.publish"
    )
  end

  teardown { Current.reset }

  test "resolver uses safe defaults without a subscription and distinguishes disabled from unknown" do
    owner = create_organization_for(name: "Default Entitlements", slug: "default-entitlements")

    disabled = resolve(owner, "crawl.manual")
    unknown = resolve(owner, "unknown.capability")

    assert_predicate disabled, :disabled?
    assert_equal false, disabled.value
    assert_equal "system_default", disabled.provenance
    assert_predicate unknown, :misconfigured?
    assert_equal "unknown", unknown.state
    assert_equal "entitlement_unknown", unknown.reason_code
  end

  test "subscribed immutable plan values return exact type state and provenance" do
    owner = subscribed_organization("starter", slug: "starter-entitlements")

    limit = resolve(owner, "projects.max")
    enabled = resolve(owner, "reports.pdf")
    disabled = resolve(owner, "crawl.javascript_rendering")

    assert_equal [ 3, "integer", "subscribed_plan_version", "enabled" ],
      [ limit.value, limit.value_type, limit.provenance, limit.state ]
    assert_predicate enabled, :enabled?
    assert_predicate disabled, :disabled?
    assert_equal false, disabled.value
  end

  test "active override wins until expiry and records actor-safe audit metadata" do
    now = Time.current.change(usec: 0)
    owner = subscribed_organization("starter", slug: "overridden-entitlements", user: @publisher)
    override = Entitlements::Public.set_organization_override(
      organization_id: owner.organization.id,
      entitlement_key: "projects.max",
      value: 9,
      starts_at: now,
      ends_at: now + 1.hour,
      reason: "Contracted temporary capacity",
      source: "contract",
      actor_membership: owner.membership,
      authorization: @platform_authorization
    )

    effective = resolve(owner, "projects.max", at: now + 30.minutes)
    expired = resolve(owner, "projects.max", at: now + 2.hours)

    assert_equal [ 9, "organization_override", override.id, "contract" ],
      [ effective.value, effective.provenance, effective.override_id, effective.override_source ]
    assert_equal [ 3, "subscribed_plan_version" ], [ expired.value, expired.provenance ]
    event = Auditing::AuditEvent.find_by!(action: "entitlement.override_set", target_id: override.id)
    assert_equal "projects.max", event.metadata.fetch("entitlement")
    refute_includes event.metadata.to_json, "Contracted temporary capacity"
  end

  test "enterprise custom limit remains contract-required until a concrete override exists" do
    owner = subscribed_organization("enterprise", slug: "enterprise-entitlements")

    resolution = resolve(owner, "projects.max")

    assert_predicate resolution, :custom_required?
    assert_nil resolution.value
    assert_equal "subscribed_plan_version", resolution.provenance
  end

  test "known entitlement missing from the subscribed version fails closed as misconfigured" do
    owner, version = subscribed_unsynchronized_version

    resolution = resolve(owner, "security.sso_saml")

    assert_equal version.id, resolution.plan_version_id
    assert_predicate resolution, :misconfigured?
    refute_predicate resolution, :enabled?
    assert_equal "entitlement_value_missing", resolution.reason_code
  end

  test "request cache reuses exact revision and invalidates after override or subscription revision" do
    owner = subscribed_organization("starter", slug: "cached-entitlements", user: @publisher)
    now = Time.current.change(usec: 0)
    first = resolve(owner, "projects.max", at: now)
    assert_same first, resolve(owner, "projects.max", at: now)

    Entitlements::Public.set_organization_override(
      organization_id: owner.organization.id,
      entitlement_key: "projects.max",
      value: 8,
      starts_at: now,
      reason: "Support-approved capacity",
      source: "support",
      actor_membership: owner.membership,
      authorization: @platform_authorization
    )
    overridden = resolve(owner, "projects.max", at: now)
    refute_same first, overridden
    assert_equal 8, overridden.value

    override = Entitlements::OrganizationOverride.find(overridden.override_id)
    Entitlements::Public.revoke_organization_override(
      organization_id: owner.organization.id,
      override_id: override.id,
      actor_membership: owner.membership,
      authorization: @platform_authorization
    )
    fallback = resolve(owner, "projects.max", at: now)
    assert_equal 3, fallback.value
    refute_same overridden, fallback

    previous_subscription = Billing::Subscription.find_by!(
      organization_id: owner.organization.id,
      status: "active"
    )
    previous_subscription.update!(status: "expired", access_state: "read_only", ended_at: Time.current)
    growth = publish_catalog_version(
      plan_key: "growth", version: 1, authorization: @platform_authorization
    )
    Billing::Public.create_subscription_reference(
      organization_id: owner.organization.id,
      plan_version_id: growth.id,
      billing_interval: "monthly"
    )
    changed_plan = resolve(owner, "projects.max", at: now)
    assert_equal 15, changed_plan.value
    refute_same fallback, changed_plan
  end

  private

  def resolve(owner, key, at: Time.current)
    Entitlements::Public.resolve(
      organization_id: owner.organization.id,
      entitlement_key: key,
      at: at
    )
  end

  def subscribed_organization(plan_key, slug:, user: create_identity_user)
    authorization = publisher_authorization(user)
    version = publish_catalog_version(plan_key: plan_key, version: 1, authorization: authorization)
    owner = create_organization_for(user: user, name: "#{plan_key.titleize} Organization", slug: slug)
    Billing::Public.create_subscription_reference(
      organization_id: owner.organization.id,
      plan_version_id: version.id,
      billing_interval: version.pricing_kind == "custom" ? "custom" : "monthly"
    )
    owner
  end

  def publisher_authorization(user)
    grant = Plans::CatalogAccessGrant.active.find_by(user_id: user.id, permission: "plan_catalog.publish")
    Plans::CatalogAccessGrant.create!(
      user_id: user.id, permission: "plan_catalog.publish", granted_at: Time.current
    ) unless grant
    Plans::Public.authorize_catalog!(user: user, permission: "plan_catalog.publish")
  end

  def subscribed_unsynchronized_version
    v1 = publish_catalog_version(plan_key: "starter", version: 1, authorization: @platform_authorization)
    path = version_two_catalog
    Plans::Public.sync_catalog(path: path)
    v2 = publish_catalog_version(
      plan_key: "starter", version: 2, authorization: @platform_authorization, path: path
    )
    owner = create_organization_for(name: "Unsynchronized Version", slug: "unsynchronized-entitlements")
    Billing::Public.create_subscription_reference(
      organization_id: owner.organization.id,
      plan_version_id: v2.id,
      billing_interval: "monthly"
    )
    [ owner, v2 ]
  ensure
    FileUtils.remove_entry(@version_two_directory) if @version_two_directory&.exist?
  end

  def version_two_catalog
    document = YAML.safe_load_file(Entitlements::Catalog::DEFAULT_PLANS_PATH, permitted_classes: [ Date ], aliases: false)
    starter = document.fetch("plans").find { |row| row.fetch("key") == "starter" }
    starter["version"] = 2
    @version_two_directory = Pathname(Dir.mktmpdir("unsynchronized-entitlement-version"))
    path = @version_two_directory.join("plans.yml")
    path.write(YAML.dump(document))
    path
  end
end
