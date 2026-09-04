# frozen_string_literal: true

require "test_helper"

class BillingSubscriptionReferenceTest < ActiveSupport::TestCase
  setup do
    Plans::Public.sync_catalog
    @publisher = create_identity_user(display_name: "Subscription Catalog Publisher")
    Plans::CatalogAccessGrant.create!(
      user_id: @publisher.id,
      permission: "plan_catalog.publish",
      granted_at: Time.current
    )
    @authorization = Plans::Public.authorize_catalog!(
      user: @publisher,
      permission: "plan_catalog.publish"
    )
    @organization = create_organization_for(name: "Versioned Customer", slug: "versioned-customer").organization
  end

  test "new plan version does not mutate an existing subscription reference or presentation snapshot" do
    starter_v1 = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 1)
    publish("starter", 1)
    subscription = Billing::Public.create_subscription_reference(
      organization_id: @organization.id,
      plan_version_id: starter_v1.id,
      billing_interval: "monthly"
    )

    Plans::Public.sync_catalog(path: catalog_with_starter_v2)
    starter_v2 = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 2)
    publish("starter", 2)

    subscription.reload
    assert_equal starter_v1.id, subscription.plan_version_id
    assert_not_equal starter_v2.id, subscription.plan_version_id
    assert_equal 1, subscription.plan_version_snapshot
    assert_equal "Starter", subscription.plan_display_name_snapshot
    assert_equal 3_900, subscription.price_cents_snapshot
    assert_equal "published", starter_v2.reload.status
  end

  test "draft plan versions and duplicate active subscriptions fail closed" do
    free = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "free" }, version: 1)
    error = assert_raises(Billing::SubscriptionConflict) do
      Billing::Public.create_subscription_reference(
        organization_id: @organization.id,
        plan_version_id: free.id,
        billing_interval: "monthly"
      )
    end
    assert_equal "plan_version_not_published", error.reason_code

    publish("free", 1)
    Billing::Public.create_subscription_reference(
      organization_id: @organization.id,
      plan_version_id: free.id,
      billing_interval: "monthly"
    )
    duplicate = assert_raises(Billing::SubscriptionConflict) do
      Billing::Public.create_subscription_reference(
        organization_id: @organization.id,
        plan_version_id: free.id,
        billing_interval: "monthly"
      )
    end
    assert_equal "active_subscription_exists", duplicate.reason_code
  end

  private

  def publish(plan_key, version)
    Plans::Public.publish_version(
      plan_key: plan_key,
      version: version,
      effective_at: Time.current,
      confirmation: "PUBLISH #{plan_key} VERSION #{version}",
      authorization: @authorization
    )
  end

  def catalog_with_starter_v2
    document = YAML.safe_load_file(Plans::Catalog::DEFAULT_PATH, permitted_classes: [ Date ], aliases: false)
    starter = document.fetch("plans").find { |row| row.fetch("key") == "starter" }
    starter["version"] = 2
    starter["display_name"] = "Starter Plus"
    starter["monthly_price_eur"] = 45
    directory = Pathname(Dir.mktmpdir("starter-v2"))
    path = directory.join("plans.yml")
    path.write(YAML.dump(document))
    @temporary_catalog_directory = directory
    path
  end

  teardown do
    FileUtils.remove_entry(@temporary_catalog_directory) if @temporary_catalog_directory&.exist?
  end
end
