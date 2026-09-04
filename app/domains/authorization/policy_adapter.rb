# frozen_string_literal: true

module Authorization
  class PolicyAdapter
    def initialize(actor_membership:, organization:, decision_service: Decision.new,
      access_boundary: AccessBoundary.new)
      @actor_membership = actor_membership
      @organization = organization
      @decision_service = decision_service
      @access_boundary = access_boundary
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

    def access_decision(**attributes)
      @access_boundary.call(access_request(**attributes))
    end

    def authorize_access!(**attributes)
      @access_boundary.authorize!(access_request(**attributes))
    end

    def with_access(**attributes, &block)
      @access_boundary.with_access(access_request(**attributes), &block)
    end

    private

    def access_request(permission_key:, **attributes)
      AccessRequest.new(
        actor_membership: @actor_membership,
        organization: @organization,
        permission_key: permission_key,
        **attributes
      )
    end
  end
end
