# frozen_string_literal: true

module Onboarding
  class CompleteDraft
    def initialize(clock: -> { Time.current }, access: Access.new, preview: BuildPlanPreview.new)
      @clock = clock
      @access = access
      @preview = preview
    end

    def call(actor_membership:, organization_id:, draft_id:)
      newly_completed = false
      completion = Draft.transaction do
        draft = @access.draft!(
          actor_membership: actor_membership,
          organization_id: organization_id,
          draft_id: draft_id,
          lock: true
        )
        next existing_completion(draft) if draft.completed?

        validate_completion!(draft, actor_membership)
        project = create_project(draft, actor_membership)
        website = create_property(
          draft, actor_membership, project,
          id: draft.website_property_id,
          kind: draft.website_kind,
          display_name: draft.website_display_name,
          configuration: { origin: draft.website_origin }
        )
        android = create_android(draft, actor_membership, project)
        ios = create_ios(draft, actor_membership, project)
        challenge = issue_verification(draft, actor_membership, project, website)
        draft.update!(state: "completed", completed_at: @clock.call)
        newly_completed = true
        Completion.new(
          draft: draft,
          project: project,
          website_property: website,
          android_property: android,
          ios_property: ios,
          challenge: challenge
        )
      end
      Instrumentation.completed if newly_completed
      completion
    end

    private

    def validate_completion!(draft, actor_membership)
      raise Conflict unless draft.current_step == "review" && draft.last_completed_step == "crawl"

      ProjectBasics.new(
        name: draft.project_name,
        slug: draft.project_slug,
        description: draft.project_description,
        default_locale: draft.default_locale,
        time_zone: draft.time_zone
      )
      ProductSelection.new(
        flow_type: draft.flow_type, add_android: draft.add_android, add_ios: draft.add_ios
      )
      PropertyDetails.new(
        website_kind: draft.website_kind,
        website_display_name: draft.website_display_name,
        website_origin: draft.website_origin,
        add_android: draft.add_android,
        android_display_name: draft.android_display_name,
        android_package_name: draft.android_package_name,
        add_ios: draft.add_ios,
        ios_display_name: draft.ios_display_name,
        ios_bundle_id: draft.ios_bundle_id,
        ios_team_id: draft.ios_team_id
      )
      VerificationChoice.new(method: draft.verification_method)
      plan = @preview.call(
        actor_membership: actor_membership,
        organization_id: draft.organization_id,
        at: @clock.call
      )
      CrawlPreferences.new(
        max_urls: draft.crawl_max_urls,
        max_depth: draft.crawl_max_depth,
        query_handling: draft.crawl_query_handling,
        obey_robots: draft.crawl_obey_robots,
        rendering: draft.crawl_rendering,
        plan_preview: plan
      )
    end

    def create_project(draft, actor_membership)
      Projects::Public.create_project(
        clock: @clock,
        id_generator: -> { draft.project_id },
        release_key_generator: -> { draft.project_release_key },
        actor_membership: actor_membership,
        name: draft.project_name,
        slug: draft.project_slug,
        description: draft.project_description,
        default_locale: draft.default_locale,
        time_zone: draft.time_zone
      )
    end

    def create_property(draft, actor_membership, project, id:, kind:, display_name:, configuration:)
      Properties::Public.create_property(
        clock: @clock,
        id_generator: -> { id },
        actor_membership: actor_membership,
        project_id: project.id,
        kind: kind,
        display_name: display_name,
        configuration: configuration
      )
    end

    def create_android(draft, actor_membership, project)
      return unless draft.add_android

      create_property(
        draft, actor_membership, project,
        id: draft.android_property_id,
        kind: "android_app",
        display_name: draft.android_display_name,
        configuration: { package_name: draft.android_package_name }
      )
    end

    def create_ios(draft, actor_membership, project)
      return unless draft.add_ios

      create_property(
        draft, actor_membership, project,
        id: draft.ios_property_id,
        kind: "ios_app",
        display_name: draft.ios_display_name,
        configuration: { bundle_id: draft.ios_bundle_id, team_id: draft.ios_team_id }
      )
    end

    def issue_verification(draft, actor_membership, project, website)
      return if draft.verification_method == "search_console"

      environment = Properties::Public.primary_environment_reference(
        organization_id: draft.organization_id,
        project_id: project.id,
        property_id: website.id
      )
      raise Conflict.new(reason_code: "onboarding_environment_missing") unless environment&.active?

      Verification::Public.issue_challenge(
        clock: @clock,
        actor_membership: actor_membership,
        project_id: project.id,
        property_id: website.id,
        environment_id: environment.id,
        method: draft.verification_method
      ).challenge
    end

    def existing_completion(draft)
      project = Projects::Public.reference(
        organization_id: draft.organization_id, project_id: draft.project_id
      )
      website = Properties::Public.reference(
        organization_id: draft.organization_id,
        project_id: draft.project_id,
        property_id: draft.website_property_id
      )
      android = if draft.add_android
        Properties::Public.reference(
          organization_id: draft.organization_id,
          project_id: draft.project_id,
          property_id: draft.android_property_id
        )
      end
      ios = if draft.add_ios
        Properties::Public.reference(
          organization_id: draft.organization_id,
          project_id: draft.project_id,
          property_id: draft.ios_property_id
        )
      end
      raise Conflict.new(reason_code: "onboarding_completion_missing") unless
        project && website && (!draft.add_android || android) && (!draft.add_ios || ios)

      Completion.new(
        draft: draft,
        project: project,
        website_property: website,
        android_property: android,
        ios_property: ios,
        challenge: nil
      )
    end
  end
end
