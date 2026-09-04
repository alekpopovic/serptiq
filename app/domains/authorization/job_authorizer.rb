# frozen_string_literal: true

module Authorization
  class JobAuthorizer
    def call(user_id:, organization_id:, permission_key:, project_id: nil, property_id: nil, resource: nil)
      Tenancy::Public.with_organization_context(user_id: user_id, organization_id: organization_id) do
        PolicyAdapter.new(
          actor_membership: Current.membership,
          organization: Current.organization
        ).authorize!(
          permission_key: permission_key,
          project: project_id,
          property: property_id,
          resource: resource
        )

        yield Current.membership, Current.organization if block_given?
      end
    end
  end
end
