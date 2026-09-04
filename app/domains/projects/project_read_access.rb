# frozen_string_literal: true

module Projects
  class ProjectReadAccess
    def visibility(actor_membership:)
      organization_id = actor_membership&.organization_id&.to_s
      membership_id = actor_membership&.id&.to_s
      subscription = Entitlements::Public.subscription_access(
        organization_id: organization_id,
        permission_key: "projects.read"
      )
      unless subscription.allow?
        raise Shared::Public::EntitlementError.new(reason_code: subscription.reason_code)
      end

      Authorization::Public.visible_project_scopes(
        organization_id: organization_id,
        membership_id: membership_id
      )
    end
  end
end
