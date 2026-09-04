# frozen_string_literal: true

module Onboarding
  class BuildReadiness
    def initialize(access: Access.new, preview: BuildPlanPreview.new)
      @access = access
      @preview = preview
    end

    def call(actor_membership:, organization_id:, draft_id:)
      draft = @access.draft!(
        actor_membership: actor_membership,
        organization_id: organization_id,
        draft_id: draft_id
      )
      raise Conflict unless draft.completed?

      project = Projects::Public.reference(
        project_id: draft.project_id, organization_id: organization_id
      )
      property = Properties::Public.reference(
        property_id: draft.website_property_id,
        project_id: draft.project_id,
        organization_id: organization_id
      )
      environment = Properties::Public.primary_environment_reference(
        property_id: draft.website_property_id,
        project_id: draft.project_id,
        organization_id: organization_id
      )
      settings_valid = valid_settings?(draft, actor_membership)
      Readiness.new(items: [
        item("project", "Project exists", project&.active?, "The project aggregate is active."),
        item(
          "origin", "Origin normalized",
          environment&.origin&.origin == draft.website_origin,
          "The primary environment stores the reviewed canonical HTTP(S) origin."
        ),
        item(
          "ownership", "Ownership verified", property&.verified?,
          property&.verified? ? "Current verification evidence is valid." :
            "Verification is pending; no ownership guarantee is shown yet."
        ),
        item(
          "settings", "Initial scan settings valid", settings_valid,
          settings_valid ? "Preferences remain within current global and plan bounds." :
            "Effective plan limits changed or manual crawling is unavailable."
        )
      ], environment_id: environment&.id)
    end

    private

    def valid_settings?(draft, actor_membership)
      plan = @preview.call(
        actor_membership: actor_membership,
        organization_id: draft.organization_id,
        at: Time.current
      )
      CrawlPreferences.new(
        max_urls: draft.crawl_max_urls,
        max_depth: draft.crawl_max_depth,
        query_handling: draft.crawl_query_handling,
        obey_robots: draft.crawl_obey_robots,
        rendering: draft.crawl_rendering,
        plan_preview: plan
      )
      true
    rescue Invalid
      false
    end

    def item(key, label, ready, detail)
      ReadinessItem.new(key: key, label: label, ready: ready, detail: detail)
    end
  end
end
