# frozen_string_literal: true

module Onboarding
  ProjectBasics = Data.define(:name, :slug, :description, :default_locale, :time_zone) do
    def initialize(name:, slug:, description:, default_locale:, time_zone:)
      normalized_name = name.to_s.strip
      normalized_slug = Projects::Public.normalize_slug(slug)
      normalized_description = description.to_s.strip
      locale = default_locale.to_s
      zone = time_zone.to_s
      errors = {}
      errors[:name] = "Enter a project name between 2 and 160 characters." unless
        normalized_name.length.between?(2, 160)
      errors[:slug] = "Enter a URL slug with 3 to 63 letters, numbers, or hyphens." unless
        Projects::Public.valid_slug?(normalized_slug)
      errors[:description] = "Keep the description under 2,000 characters." if
        normalized_description.length > 2000
      errors[:default_locale] = "Choose a supported locale." unless I18n.available_locales.map(&:to_s).include?(locale)
      errors[:time_zone] = "Choose a supported time zone." unless ActiveSupport::TimeZone[zone]
      raise Invalid.new(field_errors: errors) if errors.any?

      super(
        name: normalized_name.freeze,
        slug: normalized_slug.freeze,
        description: normalized_description.freeze,
        default_locale: locale.freeze,
        time_zone: zone.freeze
      )
      freeze
    end
  end
end
