# frozen_string_literal: true

module Properties
  class CreateEnvironment
    def initialize(clock: -> { Time.current }, id_generator: -> { SecureRandom.uuid },
      authorization: PropertyAuthorization.new)
      @clock = clock
      @id_generator = id_generator
      @authorization = authorization
    end

    def call(actor_membership:, project_id:, property_id:, key:, kind:, display_name:, origin:,
      primary: false)
      value = CanonicalOrigin.new(origin: origin)
      environment = nil
      event = nil
      Environment.transaction do
        property, _project, access = locked_access!(actor_membership, project_id, property_id)
        now = @clock.call
        primary = !!primary
        validate_primary_kind!(kind, primary)
        demote_primary!(property, now) if primary
        environment = Environment.create!(
          EnvironmentProvisioning.base_attributes(property).merge(
            id: @id_generator.call,
            key: key,
            kind: kind,
            display_name: display_name,
            primary: primary,
            status: "active",
            archived_at: nil,
            created_at: now,
            updated_at: now
          ).merge(EnvironmentProvisioning.origin_attributes(value))
        )
        if primary
          EnvironmentProvisioning.sync_configuration!(property: property, origin: value, at: now)
          reset_verification!(property)
        end
        EnvironmentAudit.record!(
          action: "property_environment.created",
          actor_membership_id: access.authorization.actor_membership_id,
          environment: environment,
          operation: "create",
          changed_fields: [ "origin", ("primary" if primary) ].compact
        )
        event = EnvironmentEvent.record!(
          environment: environment,
          event_type: "property_environment.created",
          occurred_at: now,
          actor_membership_id: access.authorization.actor_membership_id
        )
      end
      EnvironmentEvent.enqueue(event)
      environment
    end

    private

    def locked_access!(actor_membership, project_id, property_id)
      property = Property.lock.find_by(
        id: property_id,
        project_id: project_id,
        organization_id: actor_membership&.organization_id
      )
      raise PropertyAccessDenied unless property&.active? && property.kind.in?(%w[website web_application])

      project = @authorization.project!(actor_membership: actor_membership, project_id: project_id)
      access = @authorization.authorize!(
        actor_membership: actor_membership,
        permission_key: "properties.manage",
        project: project,
        property: property
      )
      [ property, project, access ]
    end

    def validate_primary_kind!(kind, primary)
      return unless primary && kind.to_s != "production"

      raise PropertyTransitionInvalid.new(reason_code: "primary_environment_must_be_production")
    end

    def demote_primary!(property, now)
      Environment.where(
        organization_id: property.organization_id,
        project_id: property.project_id,
        property_id: property.id,
        status: "active",
        primary: true
      ).update_all(primary: false, updated_at: now)
    end

    def reset_verification!(property)
      property.update!(verification_status: "unverified", verified_at: nil) unless
        property.verification_status == "unverified" && property.verified_at.nil?
    end
  end
end
