# frozen_string_literal: true

module Verification
  class Attempt < ApplicationRecord
    self.table_name = "domain_verification_attempts"

    OUTCOMES = %w[verified failed].freeze

    belongs_to :challenge, class_name: "Verification::Challenge",
      foreign_key: :domain_verification_id, inverse_of: :attempts

    validates :organization_id, :project_id, :property_id, :environment_id,
      :domain_verification_id, :attempted_at, presence: true
    validates :sequence, numericality: { only_integer: true, greater_than: 0 }, uniqueness: {
      scope: :domain_verification_id
    }
    validates :outcome, inclusion: { in: OUTCOMES }
    validates :failure_category, inclusion: { in: Challenge::FAILURE_CATEGORIES }, allow_nil: true
    validate :outcome_shape
    validate :evidence_shape

    private

    def outcome_shape
      valid = (outcome == "verified" && failure_category.nil?) ||
        (outcome == "failed" && failure_category.present?)
      errors.add(:outcome, "does not match failure category") unless valid
    end

    def evidence_shape
      valid = evidence.is_a?(Hash) && JSON.generate(evidence).bytesize <= 4.kilobytes
      errors.add(:evidence, "must be a bounded object") unless valid
    end
  end
end
