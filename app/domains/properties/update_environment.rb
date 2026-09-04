# frozen_string_literal: true

module Properties
  class UpdateEnvironment
    def initialize(clock: -> { Time.current }, authorization: PropertyAuthorization.new)
      @clock = clock
      @authorization = authorization
    end

    def call(actor_membership:, project_id:, property_id:, environment_id:, display_name:, origin:,
      primary:)
      value = CanonicalOrigin.new(origin: origin)
      result = nil
      event = nil
      Environment.transaction do
        property, environment, access = locked_access!(
          actor_membership, project_id, property_id, environment_id
        )
        now = @clock.call
        requested_primary = !!primary
        if environment.primary? && !requested_primary
          raise PropertyTransitionInvalid.new(reason_code: "primary_environment_required")
        end
        if requested_primary && environment.kind != "production"
          raise PropertyTransitionInvalid.new(reason_code: "primary_environment_must_be_production")
        end

        demote_primary!(property, environment, now) if requested_primary && !environment.primary?
        environment.assign_attributes(
          display_name: display_name,
          primary: requested_primary,
          **EnvironmentProvisioning.origin_attributes(value)
        )
        changed_fields = environment.changes.keys.map do |field|
          %w[scheme host port origin].include?(field) ? "origin" : field
        end.uniq
        changed = changed_fields.any?
        environment.save! if changed
        property.reload if changed_fields.include?("origin")
        if (changed_fields & %w[origin primary]).any?
          reset_verification!(property)
        end
        if requested_primary && (changed_fields.include?("origin") || changed_fields.include?("primary"))
          EnvironmentProvisioning.sync_configuration!(property: property, origin: value, at: now)
        end

        if changed
          EnvironmentAudit.record!(
            action: "property_environment.updated",
            actor_membership_id: access.authorization.actor_membership_id,
            environment: environment,
            operation: "update",
            changed_fields: changed_fields
          )
          event = EnvironmentEvent.record!(
            environment: environment,
            event_type: "property_environment.updated",
            occurred_at: now,
            actor_membership_id: access.authorization.actor_membership_id
          )
        end
        result = PropertyChangeResult.new(property: environment, changed: changed)
      end
      EnvironmentEvent.enqueue(event) if event
      result
    end

    private

    def locked_access!(actor_membership, project_id, property_id, environment_id)
      property = Property.lock.find_by(
        id: property_id,
        project_id: project_id,
        organization_id: actor_membership&.organization_id
      )
      raise PropertyAccessDenied unless property&.active? && property.kind.in?(%w[website web_application])

      environment = Environment.lock.find_by(
        id: environment_id,
        property_id: property.id,
        project_id: property.project_id,
        organization_id: property.organization_id
      )
      raise PropertyAccessDenied unless environment&.active?

      project = @authorization.project!(actor_membership: actor_membership, project_id: project_id)
      access = @authorization.authorize!(
        actor_membership: actor_membership,
        permission_key: "properties.manage",
        project: project,
        property: property
      )
      [ property, environment, access ]
    end

    def demote_primary!(property, environment, now)
      Environment.where(
        organization_id: property.organization_id,
        project_id: property.project_id,
        property_id: property.id,
        status: "active",
        primary: true
      ).where.not(id: environment.id).update_all(primary: false, updated_at: now)
    end

    def reset_verification!(property)
      property.update!(verification_status: "unverified", verified_at: nil) unless
        property.verification_status == "unverified" && property.verified_at.nil?
    end
  end
end
