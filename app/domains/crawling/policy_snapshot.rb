# frozen_string_literal: true

module Crawling
  class PolicySnapshot < ApplicationRecord
    self.table_name = "crawl_policy_snapshots"

    belongs_to :source_version, class_name: "Crawling::PolicyVersion",
      foreign_key: :crawl_policy_version_id

    validates :scan_id, :organization_id, :project_id, :property_id, :environment_id,
      :crawl_policy_version_id, presence: true
    validates :scan_id, uniqueness: true
    validates :policy_version, numericality: { only_integer: true, greater_than: 0 }
    validates :configuration_digest, format: { with: /\A[0-9a-f]{64}\z/ }
    validate :configuration_is_bounded_object

    def readonly?
      persisted?
    end

    def delete
      raise ActiveRecord::ReadOnlyRecord, "crawl policy snapshots are immutable"
    end

    private

    def configuration_is_bounded_object
      valid = configuration.is_a?(Hash) && JSON.generate(configuration).bytesize <= 32.kilobytes
      errors.add(:configuration, "must be a bounded object") unless valid
    end
  end
end
