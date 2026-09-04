# frozen_string_literal: true

module TestSupport
  module PropertyHelpers
    DEFAULT_CONFIGURATIONS = {
      "website" => { origin: "https://www.example.com" },
      "web_application" => { origin: "https://app.example.com" },
      "android_app" => { package_name: "com.example.android" },
      "ios_app" => { bundle_id: "com.example.ios", team_id: "A1B2C3D4E5" }
    }.freeze

    def enable_property_limits(result, website: 20, mobile: 20, at: Time.current)
      Plans::Public.sync_catalog
      Entitlements::Public.sync_catalog
      {
        "website_properties.max" => website,
        "mobile_properties.max" => mobile
      }.each do |key, value|
        next if Entitlements::OrganizationOverride.where(organization_id: result.organization.id)
          .joins(:definition).exists?(entitlement_definitions: { key: key })

        definition = Entitlements::Definition.find_by!(key: key)
        Entitlements::OrganizationOverride.create!(
          organization_id: result.organization.id,
          entitlement_definition_id: definition.id,
          value_type: "integer",
          value: value,
          starts_at: at - 1.minute,
          reason: "Property test capacity",
          source: "support",
          created_by_membership_id: result.membership.id
        )
      end
      Current.entitlement_cache = nil
    end

    def create_property_for(result, project:, kind: "website", display_name: nil,
      configuration: nil, at: Time.current)
      token = SecureRandom.hex(4)
      enable_property_limits(result, at: at)
      Properties::CreateProperty.new(clock: -> { at }).call(
        actor_membership: result.membership,
        project_id: project.id,
        kind: kind,
        display_name: display_name || "Property #{token}",
        configuration: configuration || default_property_configuration(kind, token)
      )
    end

    def default_property_configuration(kind, token = SecureRandom.hex(4))
      case kind
      when "website" then { origin: "https://#{token}.example.com" }
      when "web_application" then { origin: "https://app-#{token}.example.com" }
      when "android_app" then { package_name: "com.example.app#{token}" }
      when "ios_app" then { bundle_id: "com.example.app#{token}", team_id: "A1B2C3D4E5" }
      else DEFAULT_CONFIGURATIONS.fetch(kind)
      end
    end
  end
end
