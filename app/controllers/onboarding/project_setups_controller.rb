# frozen_string_literal: true

module Onboarding
  class ProjectSetupsController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    layout "authenticated"

    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    permission_required "projects.create", only: %i[index create show update complete destroy]

    def index
      @draft = Public.active_draft(**tenant_attributes)
      @plan_preview = Public.plan_preview(**tenant_attributes)
    end

    def create
      draft = Public.start_draft(**tenant_attributes)
      redirect_to organization_project_onboarding_draft_path(Current.organization.slug, draft.id),
        status: :see_other
    end

    def show
      load_draft
      prepare_show
    end

    def update
      draft = Public.update_draft(
        **tenant_attributes,
        draft_id: params[:draft_id],
        step: params[:step],
        direction: params[:direction],
        attributes: step_attributes
      )
      redirect_to organization_project_onboarding_draft_path(Current.organization.slug, draft.id),
        status: :see_other
    rescue Invalid => error
      load_draft
      @field_errors = error.field_errors
      prepare_show
      render :show, status: :unprocessable_content
    end

    def complete
      Public.complete_draft(**tenant_attributes, draft_id: params[:draft_id])
      redirect_to organization_project_onboarding_draft_path(
        Current.organization.slug, params[:draft_id]
      ), notice: "Project setup completed. Ownership evidence is still required before scan readiness.",
        status: :see_other
    rescue Invalid, ActiveRecord::RecordInvalid, Projects::ProjectLimitReached,
      Properties::PropertyLimitReached => error
      load_draft
      @field_errors = { base: [ completion_error(error) ] }
      prepare_show
      render :show, status: :unprocessable_content
    end

    def destroy
      Public.cancel_draft(**tenant_attributes, draft_id: params[:draft_id])
      redirect_to organization_projects_path(Current.organization.slug),
        notice: "Setup draft cancelled and its saved inputs were removed.", status: :see_other
    end

    private

    def tenant_attributes
      {
        actor_membership: Current.membership,
        organization_id: Current.organization.id
      }
    end

    def load_draft
      @draft = Public.draft(**tenant_attributes, draft_id: params[:draft_id])
    end

    def prepare_show
      @field_errors ||= {}
      @plan_preview = Public.plan_preview(**tenant_attributes)
      @readiness = Public.readiness(**tenant_attributes, draft_id: @draft.id) if @draft.completed?
      @locales = I18n.available_locales.map(&:to_s)
      @time_zones = ActiveSupport::TimeZone.all.map(&:name)
    end

    def step_attributes
      permitted = case params[:step]
      when "project" then %i[name slug description default_locale time_zone]
      when "product" then %i[flow_type add_android add_ios]
      when "property"
        %i[website_kind website_display_name website_origin android_display_name
          android_package_name ios_display_name ios_bundle_id ios_team_id]
      when "verification" then %i[verification_method]
      when "crawl" then %i[max_urls max_depth query_handling obey_robots rendering]
      else []
      end
      params.fetch(:onboarding, ActionController::Parameters.new)
        .permit(*permitted).to_h.symbolize_keys
    end

    def completion_error(error)
      case error
      when Projects::ProjectLimitReached then "The effective project limit has been reached."
      when Properties::PropertyLimitReached then "The effective property limit has been reached."
      when Invalid then error.field_errors.values.flatten.first
      else "Setup could not be completed because one of the reviewed values is no longer valid."
      end
    end

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      redirect_to organization_project_onboarding_path(Current.organization.slug),
        status: :moved_permanently
    end
  end
end
