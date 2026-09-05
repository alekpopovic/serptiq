# frozen_string_literal: true

require "test_helper"

class PropertiesRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @user = create_identity_user(display_name: "Property Owner")
    @owner = create_organization_for(user: @user, slug: "property-workspace")
    enable_project_limit(@owner, limit: 5)
    enable_property_limits(@owner, website: 40, mobile: 40)
    @project = create_project_for(@owner, slug: "property-project")
    authenticate_request(issue_identity_session(user: @user))
  end

  test "owner creates updates lists archives and reactivates a typed property" do
    assert_difference("Properties::Property.count", 1) do
      post organization_project_properties_path(@owner.organization.slug, @project.slug), params: {
        property: {
          display_name: "Public Website",
          kind: "website",
          origin: "HTTPS://WWW.EXAMPLE.COM:443/"
        }
      }
    end
    property = Properties::Property.order(:created_at).last
    assert_redirected_to organization_project_property_path(
      @owner.organization.slug, @project.slug, property.id
    )
    assert_equal "https://www.example.com", property.website_property_config.origin

    get organization_project_properties_path(@owner.organization.slug, @project.slug), params: { q: "Public" }
    assert_response :success
    assert_includes response.body, "https://www.example.com"
    assert_includes response.body, "Unverified"

    patch organization_project_property_path(@owner.organization.slug, @project.slug, property.id), params: {
      property: { display_name: "Documentation Website", origin: "https://docs.example.com" }
    }
    assert_redirected_to organization_project_property_path(
      @owner.organization.slug, @project.slug, property.id
    )
    assert_equal "Documentation Website", property.reload.display_name
    assert_equal "https://docs.example.com", property.website_property_config.reload.origin

    patch archive_organization_project_property_path(
      @owner.organization.slug, @project.slug, property.id
    )
    assert_redirected_to organization_project_properties_path(@owner.organization.slug, @project.slug)
    assert property.reload.archived?

    get organization_project_property_path(@owner.organization.slug, @project.slug, property.id)
    assert_response :success
    assert_select "button", text: "Reactivate property"

    patch reactivate_organization_project_property_path(
      @owner.organization.slug, @project.slug, property.id
    )
    assert_response :see_other
    assert property.reload.active?
  end

  test "invalid typed configuration rerenders without persisting property or scope" do
    assert_no_difference([ "Properties::Property.count", "Authorization::ScopeReference.count" ]) do
      post organization_project_properties_path(@owner.organization.slug, @project.slug), params: {
        property: {
          display_name: "Unsafe Website",
          kind: "website",
          origin: "https://user:secret@example.com/private"
        }
      }
    end

    assert_response :unprocessable_content
    assert_select "[role='alert']"
    assert_includes response.body, "must not contain credentials"
  end

  test "foreign project and nested property substitution fail closed" do
    other_project = create_project_for(@owner, slug: "other-property-project")
    property = create_property_for(@owner, project: other_project, kind: "android_app")
    foreign = create_organization_for(slug: "foreign-property-workspace")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    foreign_project = create_project_for(foreign, slug: "foreign-property-project")

    get organization_project_property_path(
      @owner.organization.slug, @project.slug, property.id
    )
    assert_response :forbidden
    refute_includes response.body, property.display_name

    post organization_project_properties_path(
      @owner.organization.slug, foreign_project.slug
    ), params: {
      property: { display_name: "Cross Tenant", kind: "android_app", package_name: "com.foreign.app" }
    }
    assert_response :forbidden
    refute Properties::Property.exists?(display_name: "Cross Tenant")
  end

  test "exact property grant filters the collection and blocks its sibling" do
    visible = create_property_for(
      @owner, project: @project, kind: "website", display_name: "Assigned Property"
    )
    hidden = create_property_for(
      @owner, project: @project, kind: "android_app", display_name: "Hidden Property"
    )
    member = add_member("Property Viewer")
    assign_role(member, "viewer", "Property", visible.id)

    reset!
    authenticate_request(issue_identity_session(user: member.user))
    get organization_project_properties_path(@owner.organization.slug, @project.slug)

    assert_response :success
    assert_includes response.body, visible.display_name
    refute_includes response.body, hidden.display_name
    assert_select "a", text: "Add property", count: 0

    get organization_project_property_path(@owner.organization.slug, @project.slug, visible.id)
    assert_response :success
    get organization_project_property_path(@owner.organization.slug, @project.slug, hidden.id)
    assert_response :forbidden
  end

  test "archived exact-property grant cannot restore but a parent-project grant can" do
    property = create_property_for(@owner, project: @project, kind: "ios_app")
    lead = add_member("Property Lead")
    assign_role(lead, "seo_lead", "Property", property.id)

    reset!
    authenticate_request(issue_identity_session(user: lead.user))
    patch archive_organization_project_property_path(
      @owner.organization.slug, @project.slug, property.id
    )
    assert_response :see_other
    assert property.reload.archived?

    patch reactivate_organization_project_property_path(
      @owner.organization.slug, @project.slug, property.id
    )
    assert_response :forbidden

    reset!
    authenticate_request(issue_identity_session(user: @user))
    assign_role(lead, "seo_lead", "Project", @project.id)
    reset!
    authenticate_request(issue_identity_session(user: lead.user))
    patch reactivate_organization_project_property_path(
      @owner.organization.slug, @project.slug, property.id
    )
    assert_response :see_other
    assert property.reload.active?
  end

  test "project detail uses the grouped active property count" do
    active = create_property_for(@owner, project: @project, kind: "website")
    archived = create_property_for(@owner, project: @project, kind: "android_app")
    Properties::Public.transition_property(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: archived.id,
      operation: "archive"
    )

    get organization_project_path(@owner.organization.slug, @project.slug)
    assert_response :success
    assert_select "section", text: /Properties\s*1/
    assert active.active?
  end

  test "property deletion requires exact confirmation and can be canceled during the hold" do
    property = create_property_for(
      @owner, project: @project, display_name: "Critical Website"
    )

    get deletion_organization_project_property_path(
      @owner.organization.slug, @project.slug, property.id
    )
    assert_response :success
    assert_includes response.body, "object deletion must reconcile successfully"

    delete organization_project_property_path(
      @owner.organization.slug, @project.slug, property.id
    ), params: { confirmation: "wrong" }
    assert_response :unprocessable_content
    assert property.reload.active?

    delete organization_project_property_path(
      @owner.organization.slug, @project.slug, property.id
    ), params: { confirmation: property.display_name }
    assert_response :see_other
    assert property.reload.pending_deletion?

    patch cancel_deletion_organization_project_property_path(
      @owner.organization.slug, @project.slug, property.id
    )
    assert_response :see_other
    assert property.reload.archived?
    assert Administration::DeletionWorkflow.find_by!(target_id: property.id).canceled?
  end

  private

  def add_member(name)
    Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: name)
    )
  end

  def assign_role(member, role_key, scope_type, scope_id)
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: member.id,
      role_id: Authorization::Role.find_by!(system: true, key: role_key).id,
      scope_type: scope_type,
      scope_id: scope_id
    )
  end
end
