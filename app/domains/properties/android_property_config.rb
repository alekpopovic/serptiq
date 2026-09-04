# frozen_string_literal: true

module Properties
  class AndroidPropertyConfig < ApplicationRecord
    self.table_name = "android_property_configs"
    self.primary_key = :property_id

    belongs_to :property, class_name: "Properties::Property", inverse_of: :android_property_config

    validates :property_kind, inclusion: { in: [ "android_app" ] }
    validates :configuration_version, inclusion: { in: [ Property::CONFIGURATION_VERSION ] }
    validates :package_name, presence: true,
      format: { with: /\A[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+\z/ },
      uniqueness: { scope: %i[organization_id project_id], case_sensitive: false }

    def value
      AndroidConfiguration.new(package_name: package_name)
    end
  end
end
