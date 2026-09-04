# frozen_string_literal: true

require "test_helper"

class DomainVerificationsRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @user = create_identity_user(display_name: "Verification Owner")
    @owner = create_organization_for(user: @user, slug: "verification-workspace")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "verification-project")
    @property = create_property_for(@owner, project: @project)
    @environment = @property.environments.sole
    authenticate_request(issue_identity_session(user: @user))
  end

  test "authorized owner issues views retries and revokes exact instructions" do
    assert_difference("Verification::Challenge.count", 1) do
      post verification_path, params: { verification: { method: "dns_txt" } }
    end
    challenge = Verification::Challenge.order(:created_at).last
    assert_redirected_to verification_path(challenge_id: challenge.id)

    follow_redirect!
    assert_response :success
    assert_includes response.body, "_searchops-verification.#{@environment.host}"
    assert_match(/searchops-verification=[A-Za-z0-9_-]{43}/, response.body)
    token = response.body.match(/searchops-verification=[A-Za-z0-9_-]{43}/)[0]
    refute_includes challenge.attributes.to_json, token

    post attempt_verification_path(challenge)
    assert_response :see_other
    assert_equal 1, challenge.reload.attempt_count
    assert_equal "pending", challenge.state
    assert_equal "provider_unavailable", challenge.attempts.sole.failure_category

    patch revoke_verification_path(challenge)
    assert_redirected_to verification_path(challenge_id: challenge.id)
    assert challenge.reload.revoked?
    assert_equal "revoked", @property.reload.verification_status
  end

  test "read-only property viewer cannot view or issue proof material" do
    viewer_user = create_identity_user(display_name: "Verification Viewer")
    viewer = Tenancy::Public.create_membership(
      actor_membership: @owner.membership, user: viewer_user
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

    get verification_path
    assert_response :forbidden
    assert_no_difference("Verification::Challenge.count") do
      post verification_path, params: { verification: { method: "meta_tag" } }
    end
    assert_response :forbidden
  end

  test "foreign and sibling challenge identifiers never disclose proof material" do
    post verification_path, params: { verification: { method: "html_file" } }
    challenge = Verification::Challenge.order(:created_at).last
    foreign = create_organization_for(slug: "verification-request-foreign")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    project = create_project_for(foreign, slug: "verification-request-project")
    property = create_property_for(foreign, project: project)
    environment = property.environments.sole

    get organization_project_property_environment_verification_path(
      foreign.organization.slug,
      project.slug,
      property.id,
      environment.id,
      challenge_id: challenge.id
    )
    assert_response :forbidden
    refute_includes response.body, challenge.challenge_digest

    sibling = Properties::Public.create_environment(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      key: "staging",
      kind: "staging",
      display_name: "Staging",
      origin: "https://staging.example.com"
    )
    get organization_project_property_environment_verification_path(
      @owner.organization.slug,
      @project.slug,
      @property.id,
      sibling.id,
      challenge_id: challenge.id
    )
    assert_response :forbidden
  end

  private

  def verification_path(challenge_id: nil)
    organization_project_property_environment_verification_path(
      @owner.organization.slug,
      @project.slug,
      @property.id,
      @environment.id,
      challenge_id: challenge_id
    )
  end

  def attempt_verification_path(challenge)
    attempt_organization_project_property_environment_verification_path(
      @owner.organization.slug,
      @project.slug,
      @property.id,
      @environment.id,
      challenge.id
    )
  end

  def revoke_verification_path(challenge)
    revoke_organization_project_property_environment_verification_path(
      @owner.organization.slug,
      @project.slug,
      @property.id,
      @environment.id,
      challenge.id
    )
  end
end
