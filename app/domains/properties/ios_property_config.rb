# frozen_string_literal: true

module Properties
  class IosPropertyConfig < ApplicationRecord
    self.table_name = "ios_property_configs"
    self.primary_key = :property_id

    belongs_to :property, class_name: "Properties::Property", inverse_of: :ios_property_config

    validates :property_kind, inclusion: { in: [ "ios_app" ] }
    validates :configuration_version, inclusion: { in: [ Property::CONFIGURATION_VERSION ] }
    validates :bundle_id, presence: true,
      format: { with: /\A[a-z][a-z0-9-]*(?:\.[a-z][a-z0-9-]*)+\z/ }
    validates :team_id, presence: true, format: { with: /\A[A-Z0-9]{10}\z/ }
    validates :bundle_id, uniqueness: {
      scope: %i[organization_id project_id team_id], case_sensitive: false
    }

    def value
      IosConfiguration.new(bundle_id: bundle_id, team_id: team_id)
    end
  end
end
