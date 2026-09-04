# frozen_string_literal: true

module Plans
  class Plan < ApplicationRecord
    self.table_name = "plans"

    KEYS = %w[free starter growth agency enterprise].freeze
    KEY_PATTERN = /\A[a-z][a-z0-9_]{0,31}\z/

    has_many :versions, class_name: "Plans::PlanVersion", inverse_of: :plan,
      dependent: :restrict_with_exception

    validates :key, inclusion: { in: KEYS }, format: { with: KEY_PATTERN }, uniqueness: true
    validates :display_order, inclusion: { in: 1..KEYS.length }, uniqueness: true
    validate :stable_key_cannot_change, on: :update
    before_destroy :protect_stable_plan!

    private

    def stable_key_cannot_change
      errors.add(:key, "is immutable") if will_save_change_to_key?
    end

    def protect_stable_plan!
      throw(:abort)
    end
  end
end
