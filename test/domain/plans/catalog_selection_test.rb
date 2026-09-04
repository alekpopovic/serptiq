# frozen_string_literal: true

require "test_helper"

class PlansCatalogSelectionTest < ActiveSupport::TestCase
  setup do
    Plans::Public.sync_catalog
    @publisher = create_identity_user(display_name: "Catalog Scheduler")
    Plans::CatalogAccessGrant.create!(
      user_id: @publisher.id,
      permission: "plan_catalog.publish",
      granted_at: Time.current
    )
    @authorization = Plans::Public.authorize_catalog!(
      user: @publisher,
      permission: "plan_catalog.publish"
    )
  end

  test "scheduled version becomes current only at its effective time" do
    starter_v1 = publish_catalog_version(plan_key: "starter", version: 1, authorization: @authorization)
    effective_at = 2.days.from_now.change(usec: 0)
    path = starter_v2_catalog
    Plans::Public.sync_catalog(path: path)
    starter_v2 = publish_catalog_version(
      plan_key: "starter",
      version: 2,
      authorization: @authorization,
      effective_at: effective_at,
      path: path
    )

    current = Plans::Public.purchasable_version(
      plan_key: "starter",
      currency: "EUR",
      billing_interval: "monthly",
      at: effective_at - 1.second
    )
    activated = Plans::Public.purchasable_version(
      plan_key: "starter",
      currency: "EUR",
      billing_interval: "annual",
      at: effective_at
    )

    assert_equal starter_v1.id, current.id
    assert_equal starter_v2.id, activated.id
  end

  test "retired or grandfathered current version blocks fallback checkout" do
    publish_catalog_version(plan_key: "starter", version: 1, authorization: @authorization)
    Administration::Public.retire_plan_version(
      plan_key: "starter",
      version: 1,
      confirmation: "RETIRE starter VERSION 1",
      authorization: @authorization
    )

    assert_raises(Plans::CatalogTargetUnavailable) do
      Plans::Public.purchasable_version(
        plan_key: "starter",
        currency: "EUR",
        billing_interval: "monthly"
      )
    end
  end

  test "upgrade downgrade and unavailable targets return explicit policies" do
    %w[free starter growth].each do |key|
      publish_catalog_version(plan_key: key, version: 1, authorization: @authorization)
    end
    starter = Plans::Public.purchasable_version(
      plan_key: "starter", currency: "EUR", billing_interval: "monthly"
    )

    upgrade = Plans::Public.plan_change_target(
      current_plan_version_id: starter.id,
      target_plan_key: "growth",
      currency: "EUR",
      billing_interval: "annual"
    )
    downgrade = Plans::Public.plan_change_target(
      current_plan_version_id: starter.id,
      target_plan_key: "free",
      currency: "EUR",
      billing_interval: "monthly"
    )

    assert_equal [ "upgrade", "immediate", "growth" ],
      [ upgrade.direction, upgrade.effective_policy, upgrade.version.plan_key ]
    assert_equal [ "downgrade", "period_end", "free" ],
      [ downgrade.direction, downgrade.effective_policy, downgrade.version.plan_key ]
    assert_raises(Plans::CatalogTargetUnavailable) do
      Plans::Public.plan_change_target(
        current_plan_version_id: starter.id,
        target_plan_key: "agency",
        currency: "USD",
        billing_interval: "monthly"
      )
    end
  end

  private

  def starter_v2_catalog
    document = YAML.safe_load_file(Plans::Catalog::DEFAULT_PATH, permitted_classes: [ Date ], aliases: false)
    starter = document.fetch("plans").find { |row| row.fetch("key") == "starter" }
    starter["version"] = 2
    starter["monthly_price_eur"] = 45
    directory = Pathname(Dir.mktmpdir("selection-v2"))
    path = directory.join("plans.yml")
    path.write(YAML.dump(document))
    @temporary_directory = directory
    path
  end

  teardown do
    FileUtils.remove_entry(@temporary_directory) if @temporary_directory&.exist?
  end
end
