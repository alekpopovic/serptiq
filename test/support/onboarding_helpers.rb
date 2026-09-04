# frozen_string_literal: true

module TestSupport
  module OnboardingHelpers
    def enable_onboarding_entitlements(result, projects: 10, websites: 10, mobile: 10,
      max_urls: 1_000, rendering: true, at: Time.current)
      enable_project_limit(result, limit: projects, at: at)
      enable_property_limits(result, website: websites, mobile: mobile, at: at)
      set_onboarding_entitlement(result, "crawl.max_urls_per_scan", max_urls, at: at)
      set_onboarding_entitlement(result, "crawl.manual", true, at: at)
      set_onboarding_entitlement(result, "crawl.javascript_rendering", rendering, at: at)
      Current.entitlement_cache = nil
    end

    def start_onboarding_draft(result)
      Onboarding::Public.start_draft(
        actor_membership: result.membership,
        organization_id: result.organization.id
      )
    end

    def advance_onboarding_draft(result, draft, flow_type: "website_only", add_android: false,
      add_ios: false, verification_method: "dns_txt", max_urls: 100, rendering: false,
      project_name: "Guided Project", project_slug: "guided-project")
      update_onboarding(result, draft, "project", {
        name: project_name,
        slug: project_slug,
        description: "Guided onboarding test",
        default_locale: "en",
        time_zone: "UTC"
      })
      update_onboarding(result, draft, "product", {
        flow_type: flow_type,
        add_android: add_android,
        add_ios: add_ios
      })
      update_onboarding(result, draft, "property", {
        website_kind: "website",
        website_display_name: "Guided Website",
        website_origin: "https://guided.example.com",
        android_display_name: "Guided Android",
        android_package_name: "com.example.guided",
        ios_display_name: "Guided iOS",
        ios_bundle_id: "com.example.guided",
        ios_team_id: "A1B2C3D4E5"
      })
      update_onboarding(result, draft, "verification", {
        verification_method: verification_method
      })
      update_onboarding(result, draft, "crawl", {
        max_urls: max_urls,
        max_depth: 5,
        query_handling: "tracking_only",
        obey_robots: true,
        rendering: rendering
      })
      draft.reload
    end

    def update_onboarding(result, draft, step, attributes, direction: "continue")
      Onboarding::Public.update_draft(
        actor_membership: result.membership,
        organization_id: result.organization.id,
        draft_id: draft.id,
        step: step,
        direction: direction,
        attributes: attributes
      )
    end

    private

    def set_onboarding_entitlement(result, key, value, at:)
      definition = Entitlements::Definition.find_by!(key: key)
      current = Entitlements::OrganizationOverride.where(
        organization_id: result.organization.id,
        entitlement_definition_id: definition.id,
        revoked_at: nil
      ).first
      return current if current

      Entitlements::OrganizationOverride.create!(
        organization_id: result.organization.id,
        entitlement_definition_id: definition.id,
        value_type: definition.value_type,
        value: value,
        starts_at: at - 1.minute,
        reason: "Onboarding test access",
        source: "support",
        created_by_membership_id: result.membership.id
      )
    end
  end
end
