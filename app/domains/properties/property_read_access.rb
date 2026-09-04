# frozen_string_literal: true

module Properties
  class PropertyReadAccess
    def visibility(actor_membership:, project:)
      subscription = Entitlements::Public.subscription_access(
        organization_id: actor_membership&.organization_id,
        permission_key: "properties.read"
      )
      unless subscription.allow?
        raise Shared::Public::EntitlementError.new(reason_code: subscription.reason_code)
      end

      Authorization::Public.visible_property_scopes(
        organization_id: actor_membership&.organization_id,
        membership_id: actor_membership&.id,
        project_id: project.id
      )
    end
  end
end
