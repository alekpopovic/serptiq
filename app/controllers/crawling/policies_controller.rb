# frozen_string_literal: true

module Crawling
  class PoliciesController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    layout "authenticated"

    before_action :establish_current_organization!
    before_action :load_scope!

    permission_required "scans.configure", only: %i[edit update reset],
      scope: -> { { project: @project, property: @property } }

    def edit
      prepare_page
    end

    def update
      Public.configure_policy(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id,
        attributes: policy_params
      )
      redirect_to edit_policy_path, notice: "Crawl policy saved as a new immutable version.",
        status: :see_other
    rescue Invalid => error
      prepare_page(form: PolicyForm.new(policy_params).apply_errors(error.field_errors))
      render :edit, status: :unprocessable_content
    end

    def reset
      Public.reset_policy(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id
      )
      redirect_to edit_policy_path, notice: "Crawl policy reset to current plan-safe defaults.",
        status: :see_other
    end

    private

    def load_scope!
      @project = Projects::Project.find_by(
        organization_id: Current.organization.id, slug: params[:project_slug]
      )
      @property = Properties::Property.find_by(
        organization_id: Current.organization.id,
        project_id: @project&.id,
        id: params[:property_id]
      )
      @environment = Properties::Environment.find_by(
        organization_id: Current.organization.id,
        project_id: @project&.id,
        property_id: @property&.id,
        id: params[:environment_id]
      )
      raise AccessDenied.new(reason_code: "crawl_policy_scope_unavailable") unless
        @project && @property&.kind&.in?(%w[website web_application]) && @environment
    end

    def prepare_page(form: nil)
      @policy_view = Public.policy(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id
      )
      @policy_form = form || PolicyForm.from_configuration(@policy_view.configuration)
    end

    def policy_params
      params.expect(crawl_policy: [
        :start_urls, :sitemap_urls, :include_patterns, :exclude_patterns,
        :max_urls, :max_depth, :query_handling, :query_parameter_allowlist,
        :query_parameter_denylist, :user_agent_suffix,
        :request_rate_per_second, :max_concurrency, :robots_behavior,
        :rendering_sample_percent, :max_rendered_pages, :artifact_retention_days
      ]).to_h.symbolize_keys
    end

    def edit_policy_path
      edit_organization_project_property_environment_crawl_policy_path(
        Current.organization.slug, @project.slug, @property.id, @environment.id
      )
    end
  end
end
