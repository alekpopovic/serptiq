# frozen_string_literal: true

require "application_system_test_case"

class BillingCheckoutFlowsSystemTest < ApplicationSystemTestCase
  setup do
    Plans::Public.sync_catalog
    @user = create_identity_user(display_name: "Billing Browser Owner")
    publish_all_plan_versions(user: @user)
    @owner = create_organization_for(user: @user, name: "Billing Browser Workspace", slug: "billing-browser")
    @starter = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "starter" }, version: 1)
    Billing::Public.create_subscription_reference(
      organization_id: @owner.organization.id,
      plan_version_id: @starter.id,
      billing_interval: "monthly"
    )
    @target = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "growth" }, version: 1)
    @previous_resolver = Plans::ComparisonsController.checkout_availability_resolver
    Plans::ComparisonsController.checkout_availability_resolver = ->(offer:, interval:) {
      offer.id == @target.id && interval == "monthly"
    }
    authenticate_system_browser(issue_identity_session(user: @user))
  end

  teardown do
    Plans::ComparisonsController.checkout_availability_resolver = @previous_resolver
    Current.reset
  end

  test "billing manager reviews an exact interval before secure hosted checkout" do
    visit organization_plan_comparison_path(@owner.organization.slug)

    click_link "Upgrade — Monthly", href: organization_plan_comparison_path(
      @owner.organization.slug,
      target_plan_key: @target.plan.key,
      billing_interval: "monthly"
    )

    assert_text "Growth selected for review"
    assert_text "No checkout has started"
    assert_button "Continue to secure monthly checkout"
    assert_no_text "variant-request"
  end

  test "checkout return explains that browser navigation is not payment proof" do
    visit organization_billing_checkout_return_path(@owner.organization.slug, paid: "true")

    assert_text "Your checkout was received"
    assert_text "Returning here does not prove payment"
    assert_text "verified and applied to the local subscription record"
    subscription = Billing::Subscription.current.find_by!(organization_id: @owner.organization.id)
    assert_equal @starter.id, subscription.plan_version_id
    assert_equal 1, Billing::Subscription.where(organization_id: @owner.organization.id).count
  end
end
