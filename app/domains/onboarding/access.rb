# frozen_string_literal: true

module Onboarding
  class Access
    REQUIRED_PERMISSIONS = %w[projects.create properties.manage properties.verify scans.configure].freeze

    def authorize!(actor_membership:, organization_id:)
      raise AccessDenied unless actor_membership&.organization_id.to_s == organization_id.to_s

      Authorization::Public.authorize_access!(
        actor_membership: actor_membership,
        permission_key: "projects.create",
        organization: organization_id
      )
      effective = Authorization::Public.effective_permissions(
        organization_id: organization_id,
        membership_id: actor_membership.id,
        scope_type: "Organization",
        scope_id: organization_id,
        all_permission_scopes: true
      )
      raise AccessDenied unless (REQUIRED_PERMISSIONS - effective.permission_keys).empty?

      actor_membership
    rescue Shared::Public::AuthorizationError
      raise AccessDenied, cause: nil
    end

    def draft!(actor_membership:, organization_id:, draft_id:, lock: false)
      authorize!(actor_membership: actor_membership, organization_id: organization_id)
      relation = lock ? Draft.lock : Draft.all
      relation.find_by!(
        id: draft_id,
        organization_id: organization_id,
        actor_membership_id: actor_membership.id
      )
    rescue ActiveRecord::RecordNotFound
      raise AccessDenied, cause: nil
    end
  end
end
