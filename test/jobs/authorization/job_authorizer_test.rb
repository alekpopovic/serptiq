# frozen_string_literal: true

require "test_helper"

class AuthorizationProtectedProbeJob < ApplicationJob
  requires_permission "projects.read"

  class_attribute :observations, default: []

  def perform(user_id:, organization_id:, project_id:)
    authorize_job!(
      user_id: user_id,
      organization_id: organization_id,
      project_id: project_id
    ) do |membership, organization|
      self.class.observations += [ [ membership.id, organization.id, project_id ] ]
    end
  end
end

class AuthorizationUndeclaredProbeJob < ApplicationJob
  def perform(user_id:, organization_id:)
    authorize_job!(user_id: user_id, organization_id: organization_id)
  end
end

class AuthorizationJobAuthorizerTest < ActiveJob::TestCase
  setup do
    Authorization::Public.sync_catalog
    AuthorizationProtectedProbeJob.observations = []
    @user = create_identity_user
    @owner = create_organization_for(user: @user, slug: "authorized-job")
    @project_id = SecureRandom.uuid
    Authorization::Public.register_scope(
      organization_id: @owner.organization.id,
      scope_type: "Project",
      scope_id: @project_id
    )
  end

  test "reloads explicit tenant context and reauthorizes before yielding" do
    AuthorizationProtectedProbeJob.perform_now(
      user_id: @user.id,
      organization_id: @owner.organization.id,
      project_id: @project_id
    )

    assert_equal [ [ @owner.membership.id, @owner.organization.id, @project_id ] ],
      AuthorizationProtectedProbeJob.observations
    assert_nil Current.user
    assert_nil Current.organization
    assert_nil Current.membership
  end

  test "rejects mismatched tenant resource and never runs application work" do
    foreign = create_organization_for(slug: "foreign-authorized-job")
    foreign_project_id = SecureRandom.uuid
    Authorization::Public.register_scope(
      organization_id: foreign.organization.id,
      scope_type: "Project",
      scope_id: foreign_project_id
    )

    error = assert_raises(Authorization::AccessDenied) do
      AuthorizationProtectedProbeJob.perform_now(
        user_id: @user.id,
        organization_id: @owner.organization.id,
        project_id: foreign_project_id
      )
    end

    assert_equal "scope_mismatch", error.reason_code
    assert_empty AuthorizationProtectedProbeJob.observations
    assert_nil Current.organization
  end

  test "rejects a stale membership when the queued job eventually runs" do
    Tenancy::Public.transition_organization(actor_membership: @owner.membership, to: "suspended")

    assert_raises(Tenancy::OrganizationAccessDenied) do
      AuthorizationProtectedProbeJob.perform_now(
        user_id: @user.id,
        organization_id: @owner.organization.id,
        project_id: @project_id
      )
    end
    assert_empty AuthorizationProtectedProbeJob.observations
    assert_nil Current.organization
  end

  test "fails closed when a user-context job omitted its policy declaration" do
    error = assert_raises(RuntimeError) do
      AuthorizationUndeclaredProbeJob.perform_now(
        user_id: @user.id,
        organization_id: @owner.organization.id
      )
    end

    assert_match(/must declare requires_permission/, error.message)
  end
end
