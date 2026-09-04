# frozen_string_literal: true

module Properties
  class TransitionProperty
    OPERATIONS = %w[archive reactivate].freeze

    def initialize(clock: -> { Time.current }, authorization: PropertyAuthorization.new,
      limit: PropertyLimit.new)
      @clock = clock
      @authorization = authorization
      @limit = limit
    end

    def call(actor_membership:, project_id:, property_id:, operation:)
      action = operation.to_s
      raise PropertyTransitionInvalid unless OPERATIONS.include?(action)

      result = nil
      outbox_event = Property.transaction do
        property = locked_property!(actor_membership, project_id, property_id)
        project = @authorization.project!(actor_membership: actor_membership, project_id: project_id)
        access = @authorization.authorize!(
          actor_membership: actor_membership,
          permission_key: "properties.manage",
          project: project,
          property: property
        )
        result = action == "archive" ? archive(property) : reactivate(property)
        record_transition!(result, access, action)
      end
      PropertyEvent.enqueue(outbox_event) if outbox_event
      result
    end

    private

    def archive(property)
      return PropertyChangeResult.new(property: property, changed: false) if property.archived?
      raise PropertyTransitionInvalid unless property.active?

      at = @clock.call
      property.update!(status: "archived", archived_at: at)
      register_scope(property, status: "archived", archived_at: at)
      PropertyChangeResult.new(property: property, changed: true)
    end

    def reactivate(property)
      return PropertyChangeResult.new(property: property, changed: false) if property.active?
      raise PropertyTransitionInvalid unless property.archived?

      at = @clock.call
      @limit.lock_and_check!(
        organization_id: property.organization_id,
        kind: property.kind,
        excluding_property_id: property.id,
        at: at
      )
      property.update!(status: "active", archived_at: nil)
      register_scope(property, status: "active", archived_at: nil)
      PropertyChangeResult.new(property: property, changed: true)
    end

    def record_transition!(result, access, operation)
      event_type = "property.#{operation == 'archive' ? 'archived' : 'reactivated'}"
      PropertyAudit.record!(
        action: result.changed? ? event_type : "property.lifecycle_ignored",
        actor_membership_id: access.authorization.actor_membership_id,
        property: result.property,
        operation: operation,
        metadata: { status: result.property.status }
      )
      return unless result.changed?

      PropertyEvent.record!(
        property: result.property,
        event_type: event_type,
        occurred_at: @clock.call,
        actor_membership_id: access.authorization.actor_membership_id
      )
    end

    def register_scope(property, status:, archived_at:)
      Authorization::Public.register_scope(
        organization_id: property.organization_id,
        scope_type: "Property",
        scope_id: property.id,
        project_id: property.project_id,
        status: status,
        archived_at: archived_at
      )
    end

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
