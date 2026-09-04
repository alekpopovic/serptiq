# frozen_string_literal: true

require "test_helper"

class PropertyEnvironmentsRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @user = create_identity_user(display_name: "Environment Owner")
    @owner = create_organization_for(user: @user, slug: "environment-workspace")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "environment-project")
    @property = create_property_for(@owner, project: @project)
    authenticate_request(issue_identity_session(user: @user))
  end

  test "owner creates searches updates archives and reactivates an environment" do
    assert_difference("Properties::Environment.count", 1) do
      post environments_path, params: {
        environment: {
          key: "staging-eu",
          kind: "staging",
          display_name: "European staging",
          origin: "https://BÜCHER.example.:443/",
          primary: "0"
        }
      }
    end
    environment = Properties::Environment.order(:created_at).last
    assert_redirected_to environment_path(environment)
    assert_equal "https://xn--bcher-kva.example", environment.origin

    get environments_path, params: { q: "staging-eu" }
    assert_response :success
    assert_includes response.body, "European staging"
    assert_includes response.body, "https://bücher.example"

    patch environment_path(environment), params: {
      environment: {
        display_name: "Staging Europe",
        origin: "https://stage.example.com:8443",
        primary: "0"
      }
    }
    assert_redirected_to environment_path(environment)
    assert_equal [ "Staging Europe", "https://stage.example.com:8443" ],
      environment.reload.values_at(:display_name, :origin)

    patch archive_environment_path(environment)
    assert_redirected_to environments_path
    assert environment.reload.archived?

    patch reactivate_environment_path(environment)
    assert_redirected_to environment_path(environment)
    assert environment.reload.active?
    refute environment.primary?
  end

  test "making another production environment primary synchronizes property origin" do
    @property.update_columns(verification_status: "verified", verified_at: 1.hour.ago)
    post environments_path, params: {
      environment: {
        key: "production-next",
        kind: "production",
        display_name: "Next production",
        origin: "https://next.example.com",
        primary: "1"
      }
    }

    assert_response :see_other
    selected = Properties::Environment.find_by!(property_id: @property.id, key: "production-next")
    assert selected.primary?
    assert_equal 1, Properties::Environment.where(property_id: @property.id, primary: true).count
    assert_equal "https://next.example.com", @property.website_property_config.reload.origin
    assert_equal "unverified", @property.reload.verification_status
  end

  test "rejects private IP non HTTP and path origins without persistence" do
    [ "http://127.0.0.1", "ftp://public.example.com", "https://public.example.com/path" ].each do |origin|
      assert_no_difference("Properties::Environment.count") do
        post environments_path, params: {
          environment: {
            key: "unsafe-#{SecureRandom.hex(2)}",
            kind: "custom",
            display_name: "Unsafe target",
            origin: origin,
            primary: "0"
          }
        }
      end
      assert_response :unprocessable_content
      assert_select "[role='alert']"
    end
  end

  test "nested and cross-tenant environment substitution fail closed" do
    sibling = create_property_for(
      @owner,
      project: @project,
      display_name: "Sibling property",
      configuration: { origin: "https://sibling.example.com" }
    )
    foreign = create_organization_for(slug: "foreign-environment-workspace")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    foreign_project = create_project_for(foreign, slug: "foreign-environment-project")
    foreign_property = create_property_for(foreign, project: foreign_project)

    get organization_project_property_environment_path(
      @owner.organization.slug,
      @project.slug,
      sibling.id,
      @property.environments.sole.id
    )
    assert_response :forbidden

    post organization_project_property_environments_path(
      @owner.organization.slug,
      foreign_project.slug,
      foreign_property.id
    ), params: {
      environment: {
        key: "foreign",
        kind: "custom",
        display_name: "Foreign",
        origin: "https://foreign-target.example.com"
      }
    }
    assert_response :forbidden
  end

  test "exact property viewer reads environments but cannot manage them" do
    viewer_user = create_identity_user(display_name: "Environment Viewer")
    viewer = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: viewer_user
    )
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: viewer.id,
      role_id: Authorization::Role.find_by!(system: true, key: "viewer").id,
      scope_type: "Property",
      scope_id: @property.id
    )
    reset!
    authenticate_request(issue_identity_session(user: viewer_user))

    get environments_path
    assert_response :success
    assert_select "a", text: "Add environment", count: 0

    post environments_path, params: {
      environment: {
        key: "blocked",
        kind: "custom",
        display_name: "Blocked",
        origin: "https://blocked.example.com"
      }
    }
    assert_response :forbidden
    refute Properties::Environment.exists?(key: "blocked")
  end

  private

  def environments_path
    organization_project_property_environments_path(
      @owner.organization.slug, @project.slug, @property.id
    )
  end

  def environment_path(environment)
    organization_project_property_environment_path(
      @owner.organization.slug, @project.slug, @property.id, environment.id
    )
  end

  def archive_environment_path(environment)
    archive_organization_project_property_environment_path(
      @owner.organization.slug, @project.slug, @property.id, environment.id
    )
  end

  def reactivate_environment_path(environment)
    reactivate_organization_project_property_environment_path(
      @owner.organization.slug, @project.slug, @property.id, environment.id
    )
  end
end
