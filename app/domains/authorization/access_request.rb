# frozen_string_literal: true

module Authorization
  AccessRequest = Data.define(
    :actor_membership_id, :actor_organization_id, :permission_key, :organization_id,
    :project_id, :property_id, :resource
  ) do
    def initialize(actor_membership:, permission_key:, organization:, project: nil, property: nil, resource: nil)
      actor_id = reference_id(actor_membership)
      actor_organization_id = if actor_membership.respond_to?(:organization_id)
        actor_membership.organization_id&.to_s
      end
      super(
        actor_membership_id: actor_id,
        actor_organization_id: actor_organization_id&.freeze,
        permission_key: permission_key.to_s.freeze,
        organization_id: reference_id(organization).to_s.freeze,
        project_id: reference_id(project),
        property_id: reference_id(property),
        resource: normalize_resource(resource)
      )
      freeze
    end

    def authenticated?
      actor_membership_id.present?
    end

    def scope_type
      return "Property" if property_id
      return "Project" if project_id

      "Organization"
    end

    def scope_id
      property_id || project_id || organization_id
    end

    private

    def reference_id(value)
      candidate = value.respond_to?(:id) ? value.id : value
      candidate&.to_s&.freeze
    end

    def normalize_resource(value)
      return if value.nil?
      return value if value.is_a?(ResourceContext)

      raise ArgumentError, "resource must be an Authorization::ResourceContext"
    end
  end
end
