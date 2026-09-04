# frozen_string_literal: true

module Properties
  class WebsitePropertyConfig < ApplicationRecord
    self.table_name = "website_property_configs"
    self.primary_key = :property_id

    belongs_to :property, class_name: "Properties::Property", inverse_of: :website_property_config

    validates :property_kind, inclusion: { in: %w[website web_application] }
    validates :configuration_version, inclusion: { in: [ Property::CONFIGURATION_VERSION ] }
    validates :scheme, inclusion: { in: %w[http https] }
    validates :host, :origin, presence: true
    validates :port, numericality: { only_integer: true, in: 1..65_535 }
    validates :origin, uniqueness: { scope: %i[organization_id project_id] }

    def value
      WebsiteConfiguration.new(origin: origin)
    end
  end
end
