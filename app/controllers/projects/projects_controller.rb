# frozen_string_literal: true

module Projects
  class ProjectsController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    layout "authenticated"

    before_action :establish_current_organization!
    before_action :redirect_alias_to_canonical_slug
    before_action :load_project!, only: %i[
      show edit update archive reactivate deletion destroy cancel_deletion
    ]

    authorization_exempt :index, reason: "scope_filtered_project_directory"
    permission_required "projects.create", only: %i[new create]
    permission_required "projects.read", only: :show, scope: -> { { project: @project } }
    permission_required "projects.update", only: %i[edit update], scope: -> { { project: @project } }
    permission_required "projects.archive", only: %i[archive reactivate], scope: -> { { project: @project } }
    permission_required "projects.delete", only: %i[deletion destroy cancel_deletion],
      scope: -> { { project: @project } }

    permission_hint "projects.create", only: :index
    permission_hint "projects.update", only: :show, scope: -> { { project: @project } }
    permission_hint "projects.archive", only: :show, scope: -> { { project: @project } }
    permission_hint "projects.delete", only: :show, scope: -> { { project: @project } }
    permission_hint "properties.read", only: :show, scope: -> { { project: @project } }
    permission_hint "properties.manage", only: :show, scope: -> { { project: @project } }
    permission_hint "properties.verify", only: :show, scope: -> { { project: @project } }
    permission_hint "scans.read", only: :show, scope: -> { { project: @project } }
    permission_hint "scans.run", only: :show, scope: -> { { project: @project } }
    permission_hint "findings.read", only: :show, scope: -> { { project: @project } }
    permission_hint "usage.read", only: :show, scope: -> { { project: @project } }
    permission_hint "integrations.read", only: :show

    def index
      @project_page = Public.project_page(
        actor_membership: Current.membership,
        number: params[:page],
        query: params[:q],
        read_models: Properties::Public.project_rollup_reader
      )
    end

    def new
      @project = Project.new(
        default_locale: Current.organization.default_locale,
        time_zone: Current.organization.time_zone
      )
      prepare_form
    end

    def create
      project = Public.create_project(
        actor_membership: Current.membership,
        **project_params.to_h.symbolize_keys
      )
      redirect_to organization_project_path(Current.organization.slug, project.slug),
        notice: "Project created.", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @project = error.record
      prepare_form
      render :new, status: :unprocessable_content
    end

    def show
      @project_summary = Public.project_details(
        actor_membership: Current.membership,
        project_id: @project.id,
        read_models: Properties::Public.project_rollup_reader
      )
      project_read = authorization_decision!("projects.read", project: @project)
      property_read = authorization_decision!("properties.read", project: @project)
      usage_read = authorization_decision!("usage.read", project: @project)
      integration_read = authorization_decision!("integrations.read")
      @can_manage_properties = authorization_decision!("properties.manage", project: @project).allow?
      @can_verify_properties = authorization_decision!("properties.verify", project: @project).allow?

      property_page, property_readiness = property_dashboard_data(property_read)
      scan_access = access_decision(
        "scans.run",
        project: @project,
        entitlement_key: "crawl.manual",
        resource: Authorization::ResourceContext.new(
          id: @project.id,
          type: "project",
          organization_id: @project.organization_id,
          scope_type: "Project",
          scope_id: @project.id,
          available: @project.scan_available?
        )
      )
      usage = if usage_read.allow?
        Usage::Public.project_readiness(
          organization_id: Current.organization.id,
          project_id: @project.id,
          authorization: usage_read
        )
      end
      integration = if integration_read.allow?
        Integrations::Public.dashboard_readiness(
          organization_id: Current.organization.id,
          authorization: integration_read
        )
      end
      activity_page = Auditing::Public.project_activity(
        organization_id: Current.organization.id,
        project_id: @project.id,
        authorization: project_read,
        page: params[:activity_page]
      )
      @project_dashboard = Public.build_dashboard(
        project: @project_summary,
        property_page: property_page,
        property_readiness: property_readiness,
        scan_read: authorization_decision!("scans.read", project: @project),
        findings_read: authorization_decision!("findings.read", project: @project),
        scan_access: scan_access,
        usage: usage,
        integration: integration,
        activity_page: activity_page
      )
      @deletion_status = Administration::Public.deletion_status(
        organization_id: Current.organization.id,
        target_type: "Project",
        target_id: @project.id
      )
    end

    def edit
      prepare_form
    end

    def update
      project = Public.update_project(
        actor_membership: Current.membership,
        project_id: @project.id,
        **editable_project_params.to_h.symbolize_keys
      )
      redirect_to organization_project_path(Current.organization.slug, project.slug),
        notice: "Project settings were updated.", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @project = error.record
      prepare_form
      render :edit, status: :unprocessable_content
    end

    def archive
      Public.transition_project(
        actor_membership: Current.membership, project_id: @project.id, operation: "archive"
      )
      redirect_to organization_projects_path(Current.organization.slug),
        notice: "Project archived. New scans are disabled.", status: :see_other
    end

    def reactivate
      Public.transition_project(
        actor_membership: Current.membership, project_id: @project.id, operation: "reactivate"
      )
      redirect_to organization_project_path(Current.organization.slug, @project.slug),
        notice: "Project reactivated.", status: :see_other
    end

    def destroy
      unless params[:confirmation].to_s == @project.slug
        prepare_deletion_review
        @confirmation_error = "Enter the exact project slug to confirm deletion."
        return render :deletion, status: :unprocessable_content
      end

      Administration::Public.request_resource_deletion(
        actor_membership: Current.membership,
        target_type: "Project",
        project_id: @project.id,
        current_session: Current.session,
        user_id: Current.user.id
      )
      redirect_to organization_project_path(Current.organization.slug, @project.slug),
        notice: "Project deletion requested. You can cancel during the retention hold.", status: :see_other
    end

    def deletion
      prepare_deletion_review
    end

    def cancel_deletion
      Administration::Public.cancel_resource_deletion(
        actor_membership: Current.membership,
        target_type: "Project",
        project_id: @project.id
      )
      redirect_to organization_project_path(Current.organization.slug, @project.slug),
        notice: "Project deletion canceled. The project remains archived.", status: :see_other
    end

    private

    def property_dashboard_data(property_read)
      return [ nil, nil ] unless property_read.allow?

      [
        Properties::Public.property_page(
          actor_membership: Current.membership,
          project_id: @project.id,
          number: params[:properties_page]
        ),
        Properties::Public.project_readiness(
          actor_membership: Current.membership,
          project_id: @project.id
        )
      ]
    end

    def load_project!
      @project = Project.find_by(
        organization_id: Current.organization.id,
        slug: params[:project_slug]
      )
      raise ProjectAccessDenied unless @project
    end

    def project_params
      params.expect(project: %i[name slug description default_locale time_zone])
    end

    def editable_project_params
      params.expect(project: %i[name description default_locale time_zone])
    end

    def prepare_form
      @locales = I18n.available_locales.map { |locale| [ locale.to_s, locale.to_s ] }.freeze
      @time_zones = ActiveSupport::TimeZone.all.map(&:name).freeze
    end

    def prepare_deletion_review
      @deletion_hold_until = Time.current + Administration::RequestResourceDeletion::GRACE_PERIOD
    end

    def redirect_alias_to_canonical_slug
      return if organization_slug_is_canonical?

      destination = if params[:project_slug].present?
        organization_project_path(Current.organization.slug, params[:project_slug])
      else
        organization_projects_path(Current.organization.slug)
      end
      redirect_to destination, status: :moved_permanently
    end
  end
end
