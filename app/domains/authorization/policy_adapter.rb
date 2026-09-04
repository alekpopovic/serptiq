# frozen_string_literal: true

module Authorization
  class PolicyAdapter
    def initialize(actor_membership:, organization:, decision_service: Decision.new)
      @actor_membership = actor_membership
      @organization = organization
      @decision_service = decision_service
    end

    def decision(permission_key:, project: nil, property: nil, resource: nil)
      @decision_service.call(AccessRequest.new(
        actor_membership: @actor_membership,
        permission_key: permission_key,
        organization: @organization,
        project: project,
        property: property,
        resource: resource
      ))
    end

    def allowed?(**attributes)
      decision(**attributes).allow?
    end

    def authorize!(**attributes)
      result = decision(**attributes)
      raise AccessDenied.new(decision: result) if result.deny?

      result
    end
  end
end
