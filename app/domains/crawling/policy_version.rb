# frozen_string_literal: true

module Crawling
  class PolicyVersion < ApplicationRecord
    self.table_name = "crawl_policy_versions"

    CHANGE_KINDS = %w[configured reset onboarding].freeze

    belongs_to :policy_set, class_name: "Crawling::PolicySet",
      foreign_key: :crawl_policy_set_id, inverse_of: :versions

    validates :organization_id, :project_id, :property_id, :environment_id,
      :created_by_membership_id, presence: true
    validates :version, numericality: { only_integer: true, greater_than: 0 },
      uniqueness: { scope: :crawl_policy_set_id }
    validates :change_kind, inclusion: { in: CHANGE_KINDS }

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "crawl policy versions are immutable"
    end

    def configuration
      PolicyConfiguration.from_record(self)
    end
  end
end
