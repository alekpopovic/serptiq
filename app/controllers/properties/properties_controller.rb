# frozen_string_literal: true

module Properties
  class PropertiesController < ApplicationController
    include Identity::LoginRequired
    include Tenancy::CurrentOrganization

    PROPERTY_TYPES = [
      [ "Website", "website" ],
      [ "Web application", "web_application" ],
      [ "Android app", "android_app" ],
      [ "iOS app", "ios_app" ]
    ].freeze

    layout "authenticated"

    before_action :establish_current_organization!
    before_action :load_project!
    before_action :load_property!, only: %i[show edit update archive reactivate]

    authorization_exempt :index, reason: "scope_filtered_property_directory"
    permission_required "properties.manage", only: %i[new create], scope: -> { { project: @project } }
    permission_required "properties.read", only: :show,
      scope: -> { { project: @project, property: @property } }
    permission_required "properties.manage", only: %i[edit update archive reactivate],
      scope: -> { { project: @project, property: @property } }

    permission_hint "properties.manage", only: :index, scope: -> { { project: @project } }
    permission_hint "properties.manage", only: :show,
      scope: -> { { project: @project, property: @property } }
    permission_hint "projects.read", only: %i[index new show], scope: -> { { project: @project } }

    def index
      @property_page = Public.property_page(
        actor_membership: Current.membership,
        project_id: @project.id,
        number: params[:page],
        query: params[:q]
      )
    end

    def new
      @property = Property.new(kind: "website", verification_status: "unverified")
      prepare_form
    end

    def create
      attributes = property_params
      property = Public.create_property(
        actor_membership: Current.membership,
        project_id: @project.id,
        kind: attributes.fetch(:kind),
        display_name: attributes.fetch(:display_name),
        configuration: configuration_for(attributes.fetch(:kind), attributes)
      )
      redirect_to organization_project_property_path(
        Current.organization.slug, @project.slug, property.id
      ), notice: "Property created.", status: :see_other
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      rebuild_invalid_property(error)
      prepare_form
      render :new, status: :unprocessable_content
    end

    def show
      @property_summary = Public.property_details(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id
      )
    end

    def edit
      prepare_form
    end

    def update
      attributes = property_params(kind: @property.kind)
      Public.update_property(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        display_name: attributes.fetch(:display_name),
        configuration: configuration_for(@property.kind, attributes)
      )
      redirect_to organization_project_property_path(
        Current.organization.slug, @project.slug, @property.id
      ), notice: "Property settings were updated.", status: :see_other
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      rebuild_invalid_property(error, existing: @property)
      prepare_form
      render :edit, status: :unprocessable_content
    end

    def archive
      Public.transition_property(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        operation: "archive"
      )
      redirect_to organization_project_properties_path(Current.organization.slug, @project.slug),
        notice: "Property archived. New scans are disabled.", status: :see_other
    end

    def reactivate
      Public.transition_property(
        actor_membership: Current.membership,
        project_id: @project.id,
        property_id: @property.id,
        operation: "reactivate"
      )
      redirect_to organization_project_property_path(
        Current.organization.slug, @project.slug, @property.id
      ), notice: "Property reactivated.", status: :see_other
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
      raise PropertyAccessDenied unless @property
    end

    def property_params(kind: nil)
      values = params.expect(property: %i[display_name kind origin package_name bundle_id team_id])
        .to_h.symbolize_keys
      values[:kind] = kind if kind
      values
    end

    def configuration_for(kind, attributes)
      case kind
      when "website", "web_application" then attributes.slice(:origin)
      when "android_app" then attributes.slice(:package_name)
      when "ios_app" then attributes.slice(:bundle_id, :team_id)
      else {}
      end
    end

    def rebuild_invalid_property(error, existing: nil)
      values = params.fetch(:property, {}).permit(
        :display_name, :kind, :origin, :package_name, :bundle_id, :team_id
      )
      @property = if error.is_a?(ActiveRecord::RecordInvalid) && error.record.is_a?(Property)
        error.record
      else
        existing || Property.new
      end
      @property.assign_attributes(values.slice(:display_name, :kind))
      @property.errors.add(:base, error.message) unless error.is_a?(ActiveRecord::RecordInvalid) &&
        error.record.equal?(@property)
      @submitted_configuration = values.to_h.symbolize_keys
    end

    def prepare_form
      @property_types = PROPERTY_TYPES
      @submitted_configuration ||= configuration_values(@property)
    end

    def configuration_values(property)
      value = property.persisted? && property.configuration_record&.value
      return {} unless value

      value.to_h
    end
  end
end
