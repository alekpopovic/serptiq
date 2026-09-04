# frozen_string_literal: true

module Plans
  class PlanVersion < ApplicationRecord
    self.table_name = "plan_versions"

    STATUSES = %w[draft published retired grandfathered].freeze
    PRICING_KINDS = %w[fixed custom].freeze
    SNAPSHOT_COLUMNS = %w[
      plan_id version display_name positioning currency pricing_kind monthly_price_cents
      annual_price_cents entitlements_snapshot catalog_checksum effective_at published_at
    ].freeze
    CHECKSUM_PATTERN = /\A[0-9a-f]{64}\z/

    belongs_to :plan, class_name: "Plans::Plan", inverse_of: :versions

    validates :version, numericality: { only_integer: true, greater_than: 0 },
      uniqueness: { scope: :plan_id }
    validates :status, inclusion: { in: STATUSES }
    validates :display_name, presence: true, length: { maximum: 80 }
    validates :positioning, presence: true, length: { maximum: 240 }
    validates :currency, format: { with: /\A[A-Z]{3}\z/ }
    validates :pricing_kind, inclusion: { in: PRICING_KINDS }
    validates :catalog_checksum, format: { with: CHECKSUM_PATTERN }
    validate :pricing_shape
    validate :lifecycle_shape
    validate :locked_snapshot_cannot_change, on: :update
    before_destroy :protect_locked_version!

    def snapshot_locked?
      status_in_database.present? && status_in_database != "draft"
    end

    def published?
      status == "published"
    end

    private

    def pricing_shape
      valid = if pricing_kind == "fixed"
        monthly_price_cents.is_a?(Integer) && monthly_price_cents >= 0 &&
          annual_price_cents.is_a?(Integer) && annual_price_cents >= 0
      else
        monthly_price_cents.nil? && annual_price_cents.nil?
      end
      errors.add(:pricing_kind, "does not match price fields") unless valid
    end

    def lifecycle_shape
      valid = case status
      when "draft"
        effective_at.nil? && published_at.nil? && retired_at.nil?
      when "published"
        effective_at.present? && published_at.present? && retired_at.nil?
      when "retired", "grandfathered"
        effective_at.present? && published_at.present? && retired_at.present?
      else
        false
      end
      errors.add(:status, "does not match lifecycle timestamps") unless valid
    end

    def locked_snapshot_cannot_change
      return unless snapshot_locked?

      errors.add(:base, "published plan versions are immutable") if
        changes_to_save.keys.intersect?(SNAPSHOT_COLUMNS)
      errors.add(:status, "requires the controlled catalog transition") if will_save_change_to_status?
    end

    def protect_locked_version!
      throw(:abort) unless status == "draft"
    end
  end
end
