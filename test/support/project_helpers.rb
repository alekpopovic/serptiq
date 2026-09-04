# frozen_string_literal: true

module TestSupport
  module ProjectHelpers
    def enable_project_limit(result, limit: 20, at: Time.current)
      Plans::Public.sync_catalog
      Entitlements::Public.sync_catalog
      definition = Entitlements::Definition.find_by!(key: "projects.max")
      Entitlements::OrganizationOverride.create!(
        organization_id: result.organization.id,
        entitlement_definition_id: definition.id,
        value_type: "integer",
        value: limit,
        starts_at: at - 1.minute,
        reason: "Project test capacity",
        source: "support",
        created_by_membership_id: result.membership.id
      )
      Current.entitlement_cache = nil
    end

    def create_project_for(result, name: nil, slug: nil, description: "", at: Time.current)
      token = SecureRandom.hex(4)
      enable_project_limit(result, at: at) unless Entitlements::OrganizationOverride
        .where(organization_id: result.organization.id)
        .joins(:definition)
        .exists?(entitlement_definitions: { key: "projects.max" })
      Projects::CreateProject.new(clock: -> { at }).call(
        actor_membership: result.membership,
        name: name || "Project #{token}",
        slug: slug || "project-#{token}",
        description: description,
        default_locale: result.organization.default_locale,
        time_zone: result.organization.time_zone
      )
    end
  end
end
