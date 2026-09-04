# frozen_string_literal: true

require "test_helper"

class OnboardingProjectSetupTest < ActiveSupport::TestCase
  class CaptureLogger
    attr_reader :entries

    def initialize
      @entries = []
    end

    %i[debug info warn error fatal].each do |severity|
      define_method(severity) { |message| entries << [ severity, message ] }
    end
  end

  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "guided-domain")
    enable_onboarding_entitlements(@owner)
    @previous_emitter = Shared::Observability.emitter
    @logger = CaptureLogger.new
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: @logger)
  end

  teardown { Shared::Observability.emitter = @previous_emitter }

  test "start is idempotent and plan preview reads capacity without reserving quota" do
    assert_no_difference([ "Usage::QuotaReservation.count", "Usage::UsageEvent.count" ]) do
      first = start_onboarding_draft(@owner)
      second = start_onboarding_draft(@owner)
      assert_equal first.id, second.id
    end

    preview = Onboarding::Public.plan_preview(
      actor_membership: @owner.membership,
      organization_id: @owner.organization.id
    )
    assert preview.projects.available?
    assert_equal 10, preview.projects.limit
    assert_equal 1_000, preview.crawl_max_urls.value
    assert preview.manual_crawl_enabled
    assert preview.rendering_enabled
    assert_equal 1, event_records.count { |event| event["event_name"] == "onboarding.started" }
  end

  test "steps are persisted for safe back forward and resume without client-owned state" do
    draft = start_onboarding_draft(@owner)
    update_onboarding(@owner, draft, "project", {
      name: "  Resumable Site  ", slug: "Resumable Site", description: "",
      default_locale: "en", time_zone: "UTC"
    })
    assert_equal "product", draft.reload.current_step
    assert_equal "Resumable Site", draft.project_name
    assert_equal "resumable-site", draft.project_slug

    duplicate = update_onboarding(@owner, draft, "project", {
      name: "Tampered duplicate", slug: "tampered", description: "",
      default_locale: "en", time_zone: "UTC"
    })
    assert_equal "product", duplicate.current_step
    assert_equal "Resumable Site", duplicate.project_name

    update_onboarding(@owner, draft, "product", {}, direction: "back")
    assert_equal "project", draft.reload.current_step
    resumed = Onboarding::Public.active_draft(
      actor_membership: @owner.membership, organization_id: @owner.organization.id
    )
    assert_equal draft.id, resumed.id
    assert_equal "Resumable Site", resumed.project_name
  end

  test "website completion is atomic idempotent and issues pending verification without scan credits" do
    draft = advance_onboarding_draft(@owner, start_onboarding_draft(@owner))
    counts = -> {
      [ Projects::Project.count, Properties::Property.count, Properties::Environment.count,
        Verification::Challenge.count, Usage::QuotaReservation.count, Usage::UsageEvent.count ]
    }

    first = nil
    assert_changes counts, from: [ 0, 0, 0, 0, 0, 0 ], to: [ 1, 1, 1, 1, 0, 0 ] do
      first = Onboarding::Public.complete_draft(
        actor_membership: @owner.membership,
        organization_id: @owner.organization.id,
        draft_id: draft.id
      )
    end
    second = Onboarding::Public.complete_draft(
      actor_membership: @owner.membership,
      organization_id: @owner.organization.id,
      draft_id: draft.id
    )

    assert_equal first.project.id, second.project.id
    assert_equal draft.project_id, first.project.id
    assert_equal draft.website_property_id, first.website_property.id
    assert first.challenge.pending?
    assert first.website_property.reload.verification_status == "pending"
    assert_equal 1, event_records.count { |event| event["event_name"] == "onboarding.completed" }
  end

  test "combined setup creates exact Android and iOS configurations" do
    draft = advance_onboarding_draft(
      @owner,
      start_onboarding_draft(@owner),
      flow_type: "combined",
      add_android: true,
      add_ios: true,
      project_slug: "combined-guided"
    )
    completion = Onboarding::Public.complete_draft(
      actor_membership: @owner.membership,
      organization_id: @owner.organization.id,
      draft_id: draft.id
    )

    assert_equal "com.example.guided", completion.android_property.configuration_record.package_name
    assert_equal "com.example.guided", completion.ios_property.configuration_record.bundle_id
    assert_equal "A1B2C3D4E5", completion.ios_property.configuration_record.team_id
    assert_equal 3, completion.project.reload.then {
      Properties::Property.where(project_id: completion.project.id).count
    }
  end

  test "current plan bounds fail closed and rollback every aggregate" do
    constrained = create_organization_for(slug: "guided-constrained")
    enable_onboarding_entitlements(constrained, max_urls: 25)
    draft = start_onboarding_draft(constrained)
    update_onboarding(constrained, draft, "project", {
      name: "Constrained", slug: "constrained", description: "", default_locale: "en", time_zone: "UTC"
    })
    update_onboarding(constrained, draft, "product", {
      flow_type: "website_only", add_android: false, add_ios: false
    })
    update_onboarding(constrained, draft, "property", {
      website_kind: "website", website_display_name: "Constrained Site",
      website_origin: "https://constrained.example.com"
    })
    update_onboarding(constrained, draft, "verification", { verification_method: "dns_txt" })

    error = assert_raises(Onboarding::Invalid) do
      update_onboarding(constrained, draft, "crawl", {
        max_urls: 26, max_depth: 5, query_handling: "tracking_only",
        obey_robots: true, rendering: false
      })
    end
    assert_match "25", error.field_errors.fetch(:max_urls).join(" ")
    assert_equal "crawl", draft.reload.current_step
    assert_equal 0, Projects::Project.where(organization_id: constrained.organization.id).count
  end

  test "draft access denies another tenant and a project-scoped invited member" do
    draft = start_onboarding_draft(@owner)
    foreign = create_organization_for(slug: "guided-foreign")
    enable_onboarding_entitlements(foreign)

    assert_raises(Onboarding::AccessDenied) do
      Onboarding::Public.draft(
        actor_membership: foreign.membership,
        organization_id: @owner.organization.id,
        draft_id: draft.id
      )
    end

    member = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Scoped Developer")
    )
    existing_project = create_project_for(@owner, slug: "scoped-existing")
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: member.id,
      role_id: Authorization::Role.find_by!(key: "developer", system: true).id,
      scope_type: "Project",
      scope_id: existing_project.id
    )
    assert_raises(Onboarding::AccessDenied) do
      Onboarding::Public.start_draft(
        actor_membership: member,
        organization_id: @owner.organization.id
      )
    end
    assert_equal 1, Onboarding::Draft.where(organization_id: @owner.organization.id).count
  end

  test "cancellation emits privacy-safe abandonment and removes all saved inputs" do
    draft = start_onboarding_draft(@owner)
    update_onboarding(@owner, draft, "project", {
      name: "Private Client", slug: "private-client", description: "Sensitive launch",
      default_locale: "en", time_zone: "UTC"
    })

    assert_difference("Onboarding::Draft.count", -1) do
      Onboarding::Public.cancel_draft(
        actor_membership: @owner.membership,
        organization_id: @owner.organization.id,
        draft_id: draft.id
      )
    end
    event = event_records.find { |record| record["event_name"] == "onboarding.abandoned" }
    assert_equal "product", event.fetch("operation")
    refute_includes event.to_json, "Private Client"
    refute_includes event.to_json, "private-client"
  end

  private

  def event_records
    @logger.entries.filter_map do |_severity, message|
      JSON.parse(message) if message.start_with?("{")
    end
  end
end
