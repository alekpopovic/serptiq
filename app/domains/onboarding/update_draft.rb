# frozen_string_literal: true

module Onboarding
  class UpdateDraft
    def initialize(access: Access.new, preview: BuildPlanPreview.new)
      @access = access
      @preview = preview
    end

    def call(actor_membership:, organization_id:, draft_id:, step:, direction:, attributes: {})
      completed_step = nil
      draft = Draft.transaction do
        value = @access.draft!(
          actor_membership: actor_membership,
          organization_id: organization_id,
          draft_id: draft_id,
          lock: true
        )
        raise Conflict.new(reason_code: "onboarding_already_completed") unless value.draft?

        requested_step = step.to_s
        raise Conflict unless Draft::STEPS.include?(requested_step)
        if direction.to_s == "back"
          move_back(value, requested_step)
        else
          result = move_forward(value, requested_step, attributes, actor_membership)
          completed_step = requested_step if result
        end
        value
      end
      Instrumentation.step_completed(completed_step) if completed_step
      draft
    end

    private

    def move_back(draft, requested_step)
      if requested_step == draft.current_step
        previous = draft.previous_step
        draft.update!(current_step: previous) if previous
      elsif Draft::STEPS.index(requested_step) == Draft::STEPS.index(draft.current_step) + 1
        return
      else
        raise Conflict
      end
      false
    end

    def move_forward(draft, requested_step, attributes, actor_membership)
      if duplicate_forward?(draft, requested_step)
        return false
      elsif requested_step != draft.current_step || requested_step == "review"
        raise Conflict
      end

      apply_step!(draft, requested_step, attributes, actor_membership)
      draft.update!(current_step: draft.next_step, last_completed_step: requested_step)
      true
    end

    def duplicate_forward?(draft, requested_step)
      draft.last_completed_step == requested_step &&
        Draft::STEPS.index(draft.current_step) == Draft::STEPS.index(requested_step) + 1
    end

    def apply_step!(draft, step, attributes, actor_membership)
      case step
      when "project" then apply_project!(draft, attributes)
      when "product" then apply_product!(draft, attributes)
      when "property" then apply_property!(draft, attributes)
      when "verification" then apply_verification!(draft, attributes)
      when "crawl" then apply_crawl!(draft, attributes, actor_membership)
      end
    end

    def apply_project!(draft, attributes)
      value = ProjectBasics.new(**attributes.slice(
        :name, :slug, :description, :default_locale, :time_zone
      ))
      draft.assign_attributes(
        project_name: value.name,
        project_slug: value.slug,
        project_description: value.description,
        default_locale: value.default_locale,
        time_zone: value.time_zone
      )
    end

    def apply_product!(draft, attributes)
      value = ProductSelection.new(**attributes.slice(:flow_type, :add_android, :add_ios))
      draft.assign_attributes(
        flow_type: value.flow_type,
        add_android: value.add_android,
        add_ios: value.add_ios
      )
      draft.assign_attributes(android_display_name: nil, android_package_name: nil) unless value.add_android
      draft.assign_attributes(ios_display_name: nil, ios_bundle_id: nil, ios_team_id: nil) unless value.add_ios
    end

    def apply_property!(draft, attributes)
      value = PropertyDetails.new(
        **attributes.slice(
          :website_kind, :website_display_name, :website_origin,
          :android_display_name, :android_package_name,
          :ios_display_name, :ios_bundle_id, :ios_team_id
        ),
        add_android: draft.add_android,
        add_ios: draft.add_ios
      )
      draft.assign_attributes(value.to_h)
    end

    def apply_verification!(draft, attributes)
      value = VerificationChoice.new(method: attributes[:verification_method])
      draft.verification_method = value.method
    end

    def apply_crawl!(draft, attributes, actor_membership)
      plan = @preview.call(
        actor_membership: actor_membership,
        organization_id: draft.organization_id,
        at: Time.current
      )
      value = CrawlPreferences.new(
        **attributes.slice(:max_urls, :max_depth, :query_handling, :obey_robots, :rendering),
        plan_preview: plan
      )
      draft.assign_attributes(
        crawl_max_urls: value.max_urls,
        crawl_max_depth: value.max_depth,
        crawl_query_handling: value.query_handling,
        crawl_obey_robots: value.obey_robots,
        crawl_rendering: value.rendering
      )
    end
  end
end
