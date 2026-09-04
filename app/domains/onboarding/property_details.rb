# frozen_string_literal: true

module Onboarding
  PropertyDetails = Data.define(
    :website_kind, :website_display_name, :website_origin,
    :android_display_name, :android_package_name,
    :ios_display_name, :ios_bundle_id, :ios_team_id
  ) do
    def initialize(website_kind:, website_display_name:, website_origin:, add_android:,
      add_ios:, android_display_name: nil, android_package_name: nil, ios_display_name: nil,
      ios_bundle_id: nil, ios_team_id: nil)
      errors = {}
      kind = website_kind.to_s
      errors[:website_kind] = "Choose Website or Web application." unless Draft::WEBSITE_KINDS.include?(kind)
      website_name = validate_name(website_display_name, :website_display_name, errors)
      website = build_configuration(kind, { origin: website_origin }, :website_origin, errors)
      android_name, android = mobile_configuration(
        add_android, android_display_name, :android_display_name, "android_app",
        { package_name: android_package_name }, :android_package_name, errors
      )
      ios_name, ios = mobile_configuration(
        add_ios, ios_display_name, :ios_display_name, "ios_app",
        { bundle_id: ios_bundle_id, team_id: ios_team_id }, :ios_bundle_id, errors
      )
      errors[:mobile_platforms] = "Property display names must be different." if
        [ website_name, android_name, ios_name ].compact.map(&:downcase).uniq.length !=
          [ website_name, android_name, ios_name ].compact.length
      raise Invalid.new(field_errors: errors) if errors.any?

      super(
        website_kind: kind.freeze,
        website_display_name: website_name.freeze,
        website_origin: website.origin.freeze,
        android_display_name: android_name&.freeze,
        android_package_name: android&.package_name&.freeze,
        ios_display_name: ios_name&.freeze,
        ios_bundle_id: ios&.bundle_id&.freeze,
        ios_team_id: ios&.team_id&.freeze
      )
      freeze
    end

    private

    def validate_name(value, field, errors)
      normalized = value.to_s.strip
      errors[field] = "Enter a display name between 2 and 160 characters." unless
        normalized.length.between?(2, 160)
      normalized
    end

    def mobile_configuration(selected, name, name_field, kind, attributes, identifier_field, errors)
      return [ nil, nil ] unless selected

      normalized_name = validate_name(name, name_field, errors)
      [ normalized_name, build_configuration(kind, attributes, identifier_field, errors) ]
    end

    def build_configuration(kind, attributes, field, errors)
      Properties::Public.normalize_configuration(kind: kind, attributes: attributes)
    rescue ArgumentError => error
      errors[field] = error.message
      nil
    end
  end
end
