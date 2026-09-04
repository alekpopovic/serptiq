# frozen_string_literal: true

module Properties
  class CreateProperty
    def initialize(clock: -> { Time.current }, id_generator: -> { SecureRandom.uuid },
      authorization: PropertyAuthorization.new, limit: PropertyLimit.new)
      @clock = clock
      @id_generator = id_generator
      @authorization = authorization
      @limit = limit
    end

    def call(actor_membership:, project_id:, kind:, display_name:, configuration:)
      typed_configuration = PropertyConfiguration.build(kind, configuration)
      project = @authorization.project!(actor_membership: actor_membership, project_id: project_id)
      now = @clock.call
      property = nil
      outbox_event = Property.transaction do
        access = @authorization.authorize!(
          actor_membership: actor_membership,
          permission_key: "properties.manage",
          project: project
        )
        @limit.lock_and_check!(
          organization_id: project.organization_id, kind: kind, at: now
        )
        property_id = @id_generator.call
        Authorization::Public.register_scope(
          organization_id: project.organization_id,
          scope_type: "Property",
          scope_id: property_id,
          project_id: project.id,
          status: "active"
        )
        property = Property.create!(
          id: property_id,
          organization_id: project.organization_id,
          project_id: project.id,
          display_name: display_name,
          kind: kind,
          status: "active",
          verification_status: "unverified",
          configuration_version: Property::CONFIGURATION_VERSION,
          authorization_scope_type: "Property",
          authorization_project_scope_type: "Project"
        )
        persist_configuration!(property, typed_configuration)
        PropertyAudit.record!(
          action: "property.created",
          actor_membership_id: access.authorization.actor_membership_id,
          property: property,
          operation: "create"
        )
        PropertyEvent.record!(
          property: property,
          event_type: "property.created",
          occurred_at: now,
          actor_membership_id: access.authorization.actor_membership_id
        )
      end
      PropertyEvent.enqueue(outbox_event)
      property
    end

    private

    def persist_configuration!(property, configuration)
      attributes = {
        property_id: property.id,
        organization_id: property.organization_id,
        project_id: property.project_id,
        property_kind: property.kind,
        configuration_version: property.configuration_version
      }.merge(configuration.database_attributes)
      case property.kind
      when "website", "web_application" then WebsitePropertyConfig.create!(attributes)
      when "android_app" then AndroidPropertyConfig.create!(attributes)
      when "ios_app" then IosPropertyConfig.create!(attributes)
      end
    end
  end
end
