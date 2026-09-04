# frozen_string_literal: true

module Properties
  class UpdateProperty
    def initialize(clock: -> { Time.current }, authorization: PropertyAuthorization.new)
      @clock = clock
      @authorization = authorization
    end

    def call(actor_membership:, project_id:, property_id:, display_name:, configuration:)
      result = nil
      outbox_events = []
      Property.transaction do
        property = locked_property!(actor_membership, project_id, property_id)
        project = @authorization.project!(actor_membership: actor_membership, project_id: project_id)
        access = @authorization.authorize!(
          actor_membership: actor_membership,
          permission_key: "properties.manage",
          project: project,
          property: property
        )
        raise PropertyTransitionInvalid.new(reason_code: "property_not_active") unless property.active?

        typed = PropertyConfiguration.build(property.kind, configuration)
        config = property.configuration_record
        raise PropertyTransitionInvalid.new(reason_code: "property_configuration_missing") unless config

        configuration_changed = config.value != typed
        property.assign_attributes(display_name: display_name)
        if configuration_changed
          property.verification_status = "unverified"
          property.verified_at = nil
        end
        property_changes = property.changes.keys
        property.save! if property.changed?
        config.assign_attributes(typed.database_attributes)
        config_changes = config.changes.keys
        config.save! if config.changed?
        environment = if configuration_changed && property.kind.in?(%w[website web_application])
          EnvironmentProvisioning.sync_primary!(
            property: property,
            configuration: typed,
            at: @clock.call
          )
        end
        changed = property_changes.any? || config_changes.any?
        property.touch(time: @clock.call) if changed && property_changes.empty?

        if changed
          changed_fields = (property_changes + (config_changes.any? ? [ "configuration" ] : [])).uniq
          PropertyAudit.record!(
            action: "property.updated",
            actor_membership_id: access.authorization.actor_membership_id,
            property: property,
            operation: "update",
            metadata: { changed_fields: changed_fields }
          )
          outbox_events << PropertyEvent.record!(
            property: property,
            event_type: "property.updated",
            occurred_at: @clock.call,
            actor_membership_id: access.authorization.actor_membership_id
          )
          if environment
            EnvironmentAudit.record!(
              action: "property_environment.updated",
              actor_membership_id: access.authorization.actor_membership_id,
              environment: environment,
              operation: "update",
              changed_fields: [ "origin" ]
            )
            outbox_events << EnvironmentEvent.record!(
              environment: environment,
              event_type: "property_environment.updated",
              occurred_at: @clock.call,
              actor_membership_id: access.authorization.actor_membership_id
            )
          end
        end
        result = PropertyChangeResult.new(property: property, changed: changed)
      end
      outbox_events.each do |event|
        event.aggregate_type == "Property" ? PropertyEvent.enqueue(event) : EnvironmentEvent.enqueue(event)
      end
      result
    end

    private

    def locked_property!(actor_membership, project_id, property_id)
      Property.lock.find_by!(
        id: property_id,
        project_id: project_id,
        organization_id: actor_membership&.organization_id
      )
    rescue ActiveRecord::RecordNotFound
      raise PropertyAccessDenied, cause: nil
    end
  end
end
