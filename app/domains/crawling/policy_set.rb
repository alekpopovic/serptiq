# frozen_string_literal: true

module Crawling
  class PolicySet < ApplicationRecord
    self.table_name = "crawl_policy_sets"

    has_many :versions, class_name: "Crawling::PolicyVersion",
      foreign_key: :crawl_policy_set_id, inverse_of: :policy_set

    validates :organization_id, :project_id, :property_id, :environment_id, presence: true
    validates :current_version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :stable_identity_is_immutable, on: :update

    def current
      return if current_version.zero?

      versions.find_by!(version: current_version)
    end

    private

    def stable_identity_is_immutable
      %i[id organization_id project_id property_id environment_id].each do |attribute|
        errors.add(attribute, "cannot be changed") if will_save_change_to_attribute?(attribute)
      end
    end
  end
end
