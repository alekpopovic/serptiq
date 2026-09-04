# frozen_string_literal: true

module Properties
  class EnvironmentsController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    ENVIRONMENT_KINDS = [
      [ "Production", "production" ],
      [ "Staging", "staging" ],
      [ "Development", "development" ],
      [ "Custom", "custom" ]
    ].freeze

    layout "authenticated"

    before_action :establish_current_organization!
    before_action :load_project!
    before_action :load_property!
    before_action :load_environment!, only: %i[show edit update archive reactivate]

    permission_required "properties.read", only: %i[index show],
      scope: -> { { project: @project, property: @property } }
    permission_required "properties.manage", only: %i[new create edit update archive reactivate],
      scope: -> { { project: @project, property: @property } }
    permission_hint "properties.manage", only: %i[index show],
      scope: -> { { project: @project, property: @property } }
    permission_hint "properties.verify", only: :show,
      scope: -> { { project: @project, property: @property } }

    def index
      @environment_page = Public.environment_page(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        number: params[:page],
        query: params[:q]
      )
    end

    def new
      @environment = Environment.new(kind: "staging", status: "active", primary: false)
      prepare_form
    end

    def create
      attributes = environment_params
      environment = Public.create_environment(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        **attributes
      )
      redirect_to environment_path(environment), notice: "Environment created.", status: :see_other
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      rebuild_invalid_environment(error)
      prepare_form
      render :new, status: :unprocessable_content
    end

    def show
      @environment_summary = Public.environment_details(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id
      )
    end

    def edit
      prepare_form
    end

    def update
      Public.update_environment(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id,
        **environment_params(kind: @environment.kind)
      )
      redirect_to environment_path(@environment), notice: "Environment updated.", status: :see_other
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      rebuild_invalid_environment(error, existing: @environment)
      prepare_form
      render :edit, status: :unprocessable_content
    end

    def archive
      Public.transition_environment(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id,
        operation: "archive"
      )
      redirect_to environments_path, notice: "Environment archived.", status: :see_other
    end

    def reactivate
      Public.transition_environment(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: @environment.id,
        operation: "reactivate"
      )
      redirect_to environment_path(@environment), notice: "Environment reactivated.", status: :see_other
    end

    private

    def load_project!
      @project = Projects::Project.find_by(
        organization_id: Current.organization.id,
        slug: params[:project_slug]
      )
      raise PropertyAccessDenied unless @project
    end

    def load_property!
      @property = Property.find_by(
        organization_id: Current.organization.id,
        project_id: @project.id,
        id: params[:property_id]
      )
      raise PropertyAccessDenied unless @property&.kind.in?(%w[website web_application])
    end

    def load_environment!
      @environment = Environment.find_by(
        organization_id: Current.organization.id,
        project_id: @project.id,
        property_id: @property.id,
        id: params[:environment_id]
      )
      raise PropertyAccessDenied unless @environment
    end

    def environment_params(kind: nil)
      values = params.expect(environment: %i[key kind display_name origin primary]).to_h.symbolize_keys
      values[:kind] = kind if kind
      values[:primary] = ActiveModel::Type::Boolean.new.cast(values[:primary])
      kind ? values.except(:key, :kind) : values
    end

    def rebuild_invalid_environment(error, existing: nil)
      values = params.fetch(:environment, {}).permit(:key, :kind, :display_name, :origin, :primary)
      @environment = if error.is_a?(ActiveRecord::RecordInvalid) && error.record.is_a?(Environment)
        error.record
      else
        existing || Environment.new
      end
      @environment.assign_attributes(values.slice(:key, :kind, :display_name, :origin, :primary))
      @environment.errors.add(:base, error.message) unless
        error.is_a?(ActiveRecord::RecordInvalid) && error.record.equal?(@environment)
    end

    def prepare_form
      @environment_kinds = ENVIRONMENT_KINDS
    end

    def environments_path
      organization_project_property_environments_path(
        Current.organization.slug, @project.slug, @property.id
      )
    end

    def environment_path(environment)
      organization_project_property_environment_path(
        Current.organization.slug, @project.slug, @property.id, environment.id
      )
    end
  end
end
