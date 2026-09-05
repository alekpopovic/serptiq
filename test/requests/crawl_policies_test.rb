# frozen_string_literal: true

require "test_helper"

class CrawlPoliciesRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @user = create_identity_user(display_name: "Crawl Policy Owner")
    @owner = create_organization_for(user: @user, slug: "crawl-policy-workspace")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    enable_crawl_policy(@owner)
    @project = create_project_for(@owner, slug: "crawl-policy-project")
    @property = create_property_for(
      @owner, project: @project,
      configuration: { origin: "https://www.example.com" }
    )
    @environment = @property.environments.sole
    authenticate_request(issue_identity_session(user: @user))
  end

  test "owner reviews saves and resets the crawl policy" do
    get policy_path

    assert_response :success
    assert_select "h1", text: "Crawl policy"
    assert_includes response.body, "Public crawl only"
    assert_includes response.body, "Plan default"
    assert_select "textarea[name='crawl_policy[query_parameter_allowlist]']"
    assert_select "textarea[name='crawl_policy[query_parameter_denylist]']"

    assert_difference("Crawling::PolicyVersion.count", 1) do
      patch policy_path, params: {
        crawl_policy: valid_crawl_policy_attributes(origin: @environment.origin)
      }
    end
    assert_redirected_to policy_path
    assert_equal 1, environment_policy_set.current_version
    assert_equal [ "session_id" ], environment_policy_set.current.query_parameter_denylist

    assert_difference("Crawling::PolicyVersion.count", 1) do
      post reset_policy_path
    end
    assert_redirected_to policy_path
    assert_equal 2, environment_policy_set.current_version
    assert_equal "reset", environment_policy_set.current.change_kind
  end

  test "invalid origin renders field errors without creating a version" do
    assert_no_difference("Crawling::PolicyVersion.count") do
      patch policy_path, params: {
        crawl_policy: valid_crawl_policy_attributes(
          origin: @environment.origin,
          start_urls: "https://foreign.example.com/"
        )
      }
    end

    assert_response :unprocessable_content
    assert_select "[role='alert']"
    assert_includes response.body, "Every URL must be an HTTP(S) URL"
  end

  test "foreign nested environment is forbidden" do
    foreign = create_organization_for(slug: "crawl-policy-request-foreign")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    enable_crawl_policy(foreign)
    project = create_project_for(foreign, slug: "foreign-policy-project")
    property = create_property_for(foreign, project: project)

    get edit_organization_project_property_environment_crawl_policy_path(
      @owner.organization.slug, project.slug, property.id, property.environments.sole.id
    )

    assert_response :forbidden
    assert_equal "authorization_denied", response.headers["X-SearchOps-Error-Code"]
  end

  private

  def policy_path
    edit_organization_project_property_environment_crawl_policy_path(
      @owner.organization.slug, @project.slug, @property.id, @environment.id
    )
  end

  def reset_policy_path
    reset_organization_project_property_environment_crawl_policy_path(
      @owner.organization.slug, @project.slug, @property.id, @environment.id
    )
  end

  def environment_policy_set
    Crawling::PolicySet.find_by!(environment_id: @environment.id)
  end
end
