# frozen_string_literal: true

require "test_helper"

class OrganizationFlowsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_identity_user
    @issued = issue_identity_session(user: @user)
    authenticate_request(@issued)
  end

  test "plain HTML creation reports validation errors and then creates an owner atomically" do
    assert_no_difference [ "Tenancy::Organization.count", "Tenancy::Membership.count" ] do
      post organizations_path, params: {
        organization: { name: "My Workspace", slug: "settings", default_locale: "en", time_zone: "UTC" }
      }
    end
    assert_response :unprocessable_content
    assert_select "[role='alert']", text: /Slug is reserved/
    assert_select "input[name='organization[name]'][value='My Workspace']"

    assert_difference [ "Tenancy::Organization.count", "Tenancy::Membership.count" ], 1 do
      post organizations_path, params: {
        organization: { name: "My Workspace", slug: "My Workspace", default_locale: "en", time_zone: "UTC" }
      }
    end
    organization = Tenancy::Organization.order(:created_at).last
    assert_redirected_to organization_dashboard_path("my-workspace")
    assert organization.current_ownership.membership.owner?
    assert_not_nil @issued.session.reload.revoked_at
  end

  test "settings rename is owner-only and old slugs redirect after membership verification" do
    owned = create_organization_for(user: @user, name: "Before", slug: "before-slug")

    patch organization_settings_path(owned.organization.slug), params: {
      organization: { name: "After", slug: "after-slug", default_locale: "en", time_zone: "UTC" }
    }
    assert_redirected_to organization_settings_path("after-slug")
    assert_equal "After", owned.organization.reload.name

    get organization_dashboard_path("before-slug")
    assert_redirected_to organization_dashboard_path("after-slug")
    assert_equal 301, response.status
  end

  test "foreign and ordinary-member settings submissions cannot mutate the organization" do
    owned = create_organization_for(user: @user, name: "Owned", slug: "owned-org")
    foreign = create_organization_for(name: "Foreign", slug: "foreign-org")

    patch organization_settings_path(foreign.organization.slug), params: {
      organization: { name: "Stolen", slug: "stolen-org", default_locale: "en", time_zone: "UTC" }
    }
    assert_response :forbidden
    assert_equal "Foreign", foreign.organization.reload.name

    Tenancy::Public.update_organization(
      actor_membership: foreign.membership,
      name: "Foreign",
      slug: "foreign-renamed"
    )
    patch organization_settings_path("foreign-org"), params: {
      organization: { name: "Alias Attack", slug: "alias-attack", default_locale: "en", time_zone: "UTC" }
    }
    assert_response :forbidden
    assert_equal "Foreign", foreign.organization.reload.name

    ordinary_membership = Tenancy::Membership.create!(
      organization: owned.organization,
      user_id: create_identity_user.id,
      status: "active",
      joined_at: Time.current
    )
    reset!
    authenticate_request(issue_identity_session(user: ordinary_membership.user))
    get organization_settings_path(owned.organization.slug)
    assert_response :forbidden
  end

  test "switch destination is allowlisted and foreign slugs are denied" do
    first = create_organization_for(user: @user, slug: "first-switch")
    second = create_organization_for(user: @user, slug: "second-switch")
    foreign = create_organization_for(slug: "foreign-switch")

    get switch_organization_path(second.organization.slug), params: { destination: "settings" }
    assert_redirected_to organization_settings_path(second.organization.slug)

    get switch_organization_path(first.organization.slug), params: { destination: "https://attacker.example" }
    assert_redirected_to organization_dashboard_path(first.organization.slug)
    refute_includes response.location, "attacker.example"

    get switch_organization_path(foreign.organization.slug), params: { destination: "dashboard" }
    assert_response :forbidden
  end

  test "suspended organizations are labelled but cannot be opened or changed" do
    result = create_organization_for(user: @user, name: "Paused Workspace", slug: "paused-workspace")
    Tenancy::Public.transition_organization(actor_membership: result.membership, to: "suspended")

    get dashboard_path
    assert_response :success
    assert_select ".so-badge-warning", text: "Suspended"
    assert_select "a[href='#{organization_dashboard_path(result.organization.slug)}']", count: 0

    get organization_dashboard_path(result.organization.slug)
    assert_response :forbidden
  end

  test "general settings expose semantic labels and no billing controls" do
    result = create_organization_for(user: @user, slug: "semantic-settings")

    get organization_settings_path(result.organization.slug)

    assert_response :success
    assert_select "nav[aria-label='Breadcrumb']"
    assert_select "label[for='organization_name']", text: "Organization name"
    assert_select "label[for='organization_slug']", text: "Organization slug"
    assert_select "form[method='post']"
    assert_select "input[name='_method'][value='patch']"
    assert_select "button", text: /checkout|subscribe|change plan/i, count: 0
    assert_select "#billing-settings-title", text: "Billing"
  end
end
