# frozen_string_literal: true

module Properties
  class TransitionProperty
    OPERATIONS = %w[archive reactivate request_deletion cancel_deletion].freeze

    def initialize(clock: -> { Time.current }, authorization: PropertyAuthorization.new,
      limit: PropertyLimit.new)
      @clock = clock
      @authorization = authorization
      @limit = limit
    end

    def call(actor_membership:, project_id:, property_id:, operation:, deletion_workflow_id: nil,
      current_session: nil, user_id: nil)
      action = operation.to_s
      raise PropertyTransitionInvalid unless OPERATIONS.include?(action)

      result = nil
      outbox_event = Property.transaction do
        property = locked_property!(actor_membership, project_id, property_id)
        project = @authorization.project!(actor_membership: actor_membership, project_id: project_id)
        verify_recent_deletion_authentication!(actor_membership, action, current_session, user_id)
        access = @authorization.authorize!(
          actor_membership: actor_membership,
          permission_key: permission_for(action),
          project: project,
          property: property
        )
        result = transition(property, action, deletion_workflow_id)
        record_transition!(result, access, action)
      end
      PropertyEvent.enqueue(outbox_event) if outbox_event
      result
    end

    private

    def transition(property, operation, deletion_workflow_id)
      case operation
      when "archive" then archive(property)
      when "reactivate" then reactivate(property)
      when "request_deletion" then request_deletion(property, deletion_workflow_id)
      when "cancel_deletion" then cancel_deletion(property, deletion_workflow_id)
      end
    end

    def archive(property)
      return PropertyChangeResult.new(property: property, changed: false) if property.archived?
      raise PropertyTransitionInvalid unless property.active?

      at = @clock.call
      property.update!(
        status: "archived",
        archived_at: at,
        work_cancellation_cutoff_at: at
      )
      register_scope(property, status: "archived", archived_at: at)
      PropertyChangeResult.new(property: property, changed: true)
    end

    def request_deletion(property, deletion_workflow_id)
      if property.pending_deletion?
        raise PropertyTransitionInvalid unless property.deletion_workflow_id == deletion_workflow_id

        return PropertyChangeResult.new(property: property, changed: false)
      end
      raise PropertyTransitionInvalid unless property.active? || property.archived?
      raise PropertyTransitionInvalid unless Shared::Public.application_uuid?(deletion_workflow_id)

      at = @clock.call
      archived_at = property.archived_at || at
      property.update!(
        status: "pending_deletion",
        archived_at: archived_at,
        deletion_requested_at: at,
        deletion_workflow_id: deletion_workflow_id,
        work_cancellation_cutoff_at: at
      )
      register_scope(property, status: "archived", archived_at: archived_at)
      PropertyChangeResult.new(property: property, changed: true)
    end

    def cancel_deletion(property, deletion_workflow_id)
      raise PropertyTransitionInvalid unless property.pending_deletion? &&
        property.deletion_workflow_id == deletion_workflow_id

      property.update!(
        status: "archived",
        deletion_requested_at: nil,
        deletion_workflow_id: nil
      )
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
      event_type = "property.#{event_suffix(operation)}"
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

    def event_suffix(operation)
      {
        "archive" => "archived",
        "reactivate" => "reactivated",
        "request_deletion" => "deletion_requested",
        "cancel_deletion" => "deletion_canceled"
      }.fetch(operation)
    end

    def permission_for(operation)
      operation.in?(%w[request_deletion cancel_deletion]) ? "projects.delete" : "properties.manage"
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

    def verify_recent_deletion_authentication!(actor_membership, operation, current_session, user_id)
      return unless operation == "request_deletion"

      membership = Tenancy::Public.authorization_membership(
        organization_id: actor_membership&.organization_id,
        membership_id: actor_membership&.id
      )
      raise PropertyAccessDenied unless membership&.active? && membership.user_id == user_id.to_s

      Identity::Public.verify_recent_session!(
        session: current_session,
        user_id: membership.user_id,
        clock: @clock
      )
    end
  end
end
