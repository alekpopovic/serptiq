# frozen_string_literal: true

require "test_helper"

class ScopedResourceAccessRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @owner_user = create_identity_user(display_name: "Scoped Access Owner")
    @owner = create_organization_for(
      user: @owner_user, name: "Scoped Access Workspace", slug: "scoped-access-workspace"
    )
    enable_project_limit(@owner, limit: 10)
    enable_property_limits(@owner, website: 10, mobile: 10)
    @project_one = create_project_for(
      @owner, name: "Permitted Client Project", slug: "permitted-client-project"
    )
    @project_two = create_project_for(
      @owner, name: "Restricted Sibling Project", slug: "restricted-sibling-project"
    )
    @property_one = create_property_for(
      @owner, project: @project_one, display_name: "Permitted Client Property"
    )
    @property_one_sibling = create_property_for(
      @owner, project: @project_one, display_name: "Permitted Project Sibling"
    )
    @property_two = create_property_for(
      @owner, project: @project_two, display_name: "Restricted Sibling Property"
    )
    @environment_one = @property_one.environments.sole
    @environment_one_sibling = Properties::Public.create_environment(
      actor_membership: @owner.membership,
      project_id: @project_one.id,
      property_id: @property_one.id,
      key: "staging",
      kind: "staging",
      display_name: "Permitted Staging",
      origin: "https://staging.permitted.example.com"
    )
    @environment_two = @property_two.environments.sole
    @issued = Verification::Public.issue_challenge(
      actor_membership: @owner.membership,
      project_id: @project_one.id,
      property_id: @property_one.id,
      environment_id: @environment_one.id,
      method: "dns_txt"
    )
  end

  test "project search and property counts disclose only the authorized scope" do
    member = add_member("Scoped Request Viewer")
    assign(member, "viewer", "Project", @project_one.id)
    authenticate_as(member)

    get organization_projects_path(@owner.organization.slug), params: { q: "Restricted" }
    assert_response :success
    refute_includes response.body, @project_two.name
    refute_includes response.body, @property_two.display_name
    assert_select "tbody tr", count: 0

    get organization_projects_path(@owner.organization.slug)
    assert_response :success
    assert_includes response.body, @project_one.name
    refute_includes response.body, @project_two.name
    assert_select "tbody tr", count: 1

    get organization_project_properties_path(
      @owner.organization.slug, @project_one.slug
    )
    assert_response :success
    assert_select "tbody tr", count: 2

    get organization_project_properties_path(
      @owner.organization.slug, @project_two.slug
    )
    assert_response :forbidden
    refute_includes response.body, @project_two.name
    refute_includes response.body, @property_two.display_name
  end

  test "nested property environment challenge and crawl-policy substitutions fail closed" do
    member = add_member("Scoped Request Developer")
    assign(member, "developer", "Project", @project_one.id)
    authenticate_as(member)

    get organization_project_property_path(
      @owner.organization.slug, @project_one.slug, @property_two.id
    )
    assert_response :forbidden
    refute_includes response.body, @property_two.display_name

    get organization_project_property_environment_path(
      @owner.organization.slug,
      @project_one.slug,
      @property_one.id,
      @environment_two.id
    )
    assert_response :forbidden
    refute_includes response.body, @environment_two.origin

    get organization_project_property_environment_verification_path(
      @owner.organization.slug,
      @project_one.slug,
      @property_one.id,
      @environment_one_sibling.id,
      challenge_id: @issued.challenge.id
    )
    assert_response :forbidden
    refute_includes response.body, @issued.instructions.value

    get edit_organization_project_property_environment_crawl_policy_path(
      @owner.organization.slug,
      @project_one.slug,
      @property_one.id,
      @environment_two.id
    )
    assert_response :forbidden
    refute_includes response.body, @environment_two.origin
  end

  test "property-only access does not expose its parent project or sibling" do
    member = add_member("Exact Property Viewer")
    assign(member, "viewer", "Property", @property_one.id)
    authenticate_as(member)

    get organization_project_properties_path(
      @owner.organization.slug, @project_one.slug
    )
    assert_response :success
    assert_includes response.body, @property_one.display_name
    refute_includes response.body, @property_one_sibling.display_name
    refute_includes response.body, @project_one.name
    assert_select "a", text: "Projects", count: 0
    assert_select "a", text: @project_one.name, count: 0

    get organization_projects_path(@owner.organization.slug)
    assert_response :forbidden
    refute_includes response.body, @project_one.name

    get organization_project_path(@owner.organization.slug, @project_one.slug)
    assert_response :forbidden
    refute_includes response.body, @project_one.name
  end

  test "active membership with no resource grant is denied before an index response" do
    member = add_member("Unassigned Member")
    authenticate_as(member)

    get organization_projects_path(@owner.organization.slug)
    assert_response :forbidden
    refute_includes response.body, @project_one.name

    get organization_project_properties_path(
      @owner.organization.slug, @project_one.slug
    )
    assert_response :forbidden
    refute_includes response.body, @project_one.name
    refute_includes response.body, @property_one.display_name
  end

  private

  def add_member(name)
    Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: name)
    )
  end

  def assign(member, role_key, scope_type, scope_id)
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: member.id,
      role_id: Authorization::Role.find_by!(system: true, key: role_key).id,
      scope_type: scope_type,
      scope_id: scope_id
    )
  end

  def authenticate_as(member)
    reset!
    authenticate_request(issue_identity_session(user: member.user))
  end
end
