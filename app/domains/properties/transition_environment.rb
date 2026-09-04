# frozen_string_literal: true

module Properties
  class TransitionEnvironment
    OPERATIONS = %w[archive reactivate].freeze

    def initialize(clock: -> { Time.current }, authorization: PropertyAuthorization.new)
      @clock = clock
      @authorization = authorization
    end

    def call(actor_membership:, project_id:, property_id:, environment_id:, operation:)
      raise ArgumentError, "environment operation is invalid" unless operation.in?(OPERATIONS)

      environment = nil
      event = nil
      Environment.transaction do
        property = Property.lock.find_by(
          id: property_id,
          project_id: project_id,
          organization_id: actor_membership&.organization_id
        )
        raise PropertyAccessDenied unless property&.active?

        environment = Environment.lock.find_by(
          id: environment_id,
          property_id: property.id,
          project_id: property.project_id,
          organization_id: property.organization_id
        )
        raise PropertyAccessDenied unless environment
        project = @authorization.project!(actor_membership: actor_membership, project_id: project_id)
        access = @authorization.authorize!(
          actor_membership: actor_membership,
          permission_key: "properties.manage",
          project: project,
          property: property
        )
        return environment if idempotent?(environment, operation)
        if operation == "archive" && environment.primary?
          raise PropertyTransitionInvalid.new(reason_code: "primary_environment_required")
        end

        now = @clock.call
        operation == "archive" ? environment.archive!(now) : environment.reactivate!
        EnvironmentAudit.record!(
          action: "property_environment.#{operation}d",
          actor_membership_id: access.authorization.actor_membership_id,
          environment: environment,
          operation: operation,
          changed_fields: %w[status archived_at]
        )
        event = EnvironmentEvent.record!(
          environment: environment,
          event_type: "property_environment.#{operation}d",
          occurred_at: now,
          actor_membership_id: access.authorization.actor_membership_id
        )
      end
      EnvironmentEvent.enqueue(event)
      environment
    end

    private

    def idempotent?(environment, operation)
      (operation == "archive" && environment.archived?) ||
        (operation == "reactivate" && environment.active?)
    end
  end
end
