# frozen_string_literal: true

require "test_helper"

class ProjectOnboardingRequestTest < ActionDispatch::IntegrationTest
  setup do
    Authorization::Public.sync_catalog
    @user = create_identity_user(display_name: "Guided Owner")
    @owner = create_organization_for(user: @user, slug: "guided-request")
    enable_onboarding_entitlements(@owner)
    authenticate_request(issue_identity_session(user: @user))
  end

  test "accessible no-JavaScript entry shows factual plan effects and creates one resumable draft" do
    get organization_project_onboarding_path(@owner.organization.slug)

    assert_response :success
    assert_select "h1", text: "Set up a project and its properties"
    assert_select "form[action='#{organization_project_onboarding_path(@owner.organization.slug)}'][method='post']"
    assert_select "aside[aria-labelledby='onboarding-plan-impact-title']"
    assert_select "main", count: 1
    assert_includes response.body, "No scan credits are reserved"

    assert_difference("Onboarding::Draft.count", 1) do
      post organization_project_onboarding_path(@owner.organization.slug)
    end
    draft = Onboarding::Draft.last
    assert_redirected_to organization_project_onboarding_draft_path(@owner.organization.slug, draft.id)

    post organization_project_onboarding_path(@owner.organization.slug)
    assert_redirected_to organization_project_onboarding_draft_path(@owner.organization.slug, draft.id)
    assert_equal 1, Onboarding::Draft.active.count
  end

  test "invalid step rerenders associated server errors without trusting hidden business state" do
    draft = start_onboarding_draft(@owner)

    patch organization_project_onboarding_step_path(
      @owner.organization.slug, draft.id, "project"
    ), params: {
      direction: "continue",
      onboarding: { name: "X", slug: "?", description: "", default_locale: "en", time_zone: "UTC" }
    }

    assert_response :unprocessable_content
    assert_select "[role='alert']"
    assert_select "form[method='post'] input[name='_method'][value='patch']"
    assert_select "input[type='hidden'][name='onboarding[current_step]']", count: 0
    assert_equal "project", draft.reload.current_step
    assert_equal 0, Projects::Project.count
  end

  test "completion duplicate is idempotent and reserves no quota" do
    draft = advance_onboarding_draft(@owner, start_onboarding_draft(@owner))
    path = complete_organization_project_onboarding_path(@owner.organization.slug, draft.id)

    assert_difference([ "Projects::Project.count", "Properties::Property.count" ], 1) do
      assert_no_difference([ "Usage::QuotaReservation.count", "Usage::UsageEvent.count" ]) do
        post path
      end
    end
    assert_response :see_other
    post path
    assert_response :see_other
    assert_equal 1, Projects::Project.count
    assert_equal 1, Properties::Property.count

    get organization_project_onboarding_draft_path(@owner.organization.slug, draft.id)
    assert_response :success
    assert_select "h2", text: "Factual readiness checklist"
    assert_select "li", text: /Ownership verified.*Not ready/m
    assert_includes response.body, "reserved zero scan credits"
  end

  test "foreign and project-scoped users cannot enumerate or mutate drafts" do
    draft = start_onboarding_draft(@owner)
    foreign = create_organization_for(slug: "guided-request-foreign")

    get organization_project_onboarding_draft_path(foreign.organization.slug, draft.id)
    assert_response :forbidden
    refute_includes response.body, draft.id

    member = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Scoped Wizard User")
    )
    project = create_project_for(@owner, slug: "scoped-wizard-project")
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: member.id,
      role_id: Authorization::Role.find_by!(key: "developer", system: true).id,
      scope_type: "Project",
      scope_id: project.id
    )
    reset!
    authenticate_request(issue_identity_session(user: member.user))
    get organization_project_onboarding_path(@owner.organization.slug)
    assert_response :forbidden
    assert_equal 1, Onboarding::Draft.active.count
  end

  test "cancel removes the draft without creating aggregates" do
    draft = start_onboarding_draft(@owner)

    assert_difference("Onboarding::Draft.count", -1) do
      assert_no_difference([ "Projects::Project.count", "Properties::Property.count" ]) do
        delete organization_project_onboarding_draft_path(@owner.organization.slug, draft.id)
      end
    end
    assert_redirected_to organization_projects_path(@owner.organization.slug)
  end
end
