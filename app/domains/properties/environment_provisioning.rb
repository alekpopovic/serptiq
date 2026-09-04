# frozen_string_literal: true

module Properties
  module EnvironmentProvisioning
    module_function

    def create_primary!(property:, configuration:, at:)
      return unless property.kind.in?(%w[website web_application])

      Environment.create!(
        base_attributes(property).merge(
          id: SecureRandom.uuid,
          key: "production",
          kind: "production",
          display_name: "Production",
          primary: true,
          status: "active",
          archived_at: nil,
          created_at: at,
          updated_at: at
        ).merge(origin_attributes(configuration))
      )
    end

    def sync_primary!(property:, configuration:, at:)
      environment = Environment.lock.find_by!(
        organization_id: property.organization_id,
        project_id: property.project_id,
        property_id: property.id,
        status: "active",
        primary: true,
        kind: "production"
      )
      environment.update!(origin_attributes(configuration).merge(updated_at: at))
      environment
    end

    def sync_configuration!(property:, origin:, at:)
      configuration = property.website_property_config
      raise PropertyTransitionInvalid.new(reason_code: "property_configuration_missing") unless configuration

      configuration.update!(origin_attributes(origin).merge(updated_at: at))
      configuration
    end

    def base_attributes(property)
      {
        organization_id: property.organization_id,
        project_id: property.project_id,
        property_id: property.id,
        property_kind: property.kind,
        configuration_version: property.configuration_version
      }
    end

    def origin_attributes(configuration)
      value = configuration.is_a?(CanonicalOrigin) ? configuration :
        CanonicalOrigin.new(origin: configuration.origin)
      { origin: value.origin, scheme: value.scheme, host: value.host, port: value.port }
    end
  end
end
