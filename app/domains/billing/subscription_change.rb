# frozen_string_literal: true

module Billing
  class SubscriptionChange < ApplicationRecord
    self.table_name = "billing_subscription_changes"

    DIRECTIONS = %w[upgrade downgrade].freeze
    POLICIES = %w[immediate period_end].freeze
    STATES = %w[pending scheduled submitted applied failed canceled].freeze
    ACTIVE_STATES = %w[pending scheduled submitted].freeze
    DIGEST_PATTERN = /\A[0-9a-f]{64}\z/

    belongs_to :subscription, class_name: "Billing::Subscription"

    validates :organization_id, :subscription_id, :from_plan_version_id,
      :target_plan_version_id, :requested_by_membership_id, presence: true
    validates :target_billing_interval, inclusion: { in: %w[monthly annual] }
    validates :direction, inclusion: { in: DIRECTIONS }
    validates :effective_policy, inclusion: { in: POLICIES }
    validates :state, inclusion: { in: STATES }
    validates :idempotency_digest, :request_checksum, format: { with: DIGEST_PATTERN }
    validates :requested_at, :effective_at, presence: true
    validate :identifier_shapes
    validate :change_shape
    validate :lifecycle_shape

    scope :active, -> { where(state: ACTIVE_STATES) }

    def summary
      SubscriptionChangeSummary.new(
        id: id,
        organization_id: organization_id,
        subscription_id: subscription_id,
        from_plan_version_id: from_plan_version_id,
        target_plan_version_id: target_plan_version_id,
        target_billing_interval: target_billing_interval,
        direction: direction,
        effective_policy: effective_policy,
        state: state,
        effective_at: effective_at
      )
    end

    private

    def identifier_shapes
      %i[
        organization_id subscription_id from_plan_version_id target_plan_version_id
        requested_by_membership_id
      ].each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
    end

    def change_shape
      errors.add(:target_plan_version_id, "must differ from the current plan") if
        from_plan_version_id == target_plan_version_id
      errors.add(:effective_at, "cannot precede the request") if
        effective_at && requested_at && effective_at < requested_at
      errors.add(:dispatch_enqueued_at, "cannot precede the request") if
        dispatch_enqueued_at && requested_at && dispatch_enqueued_at < requested_at
      valid = (direction == "upgrade" && effective_policy == "immediate" && state != "scheduled") ||
        (direction == "downgrade" && effective_policy == "period_end" && state != "pending")
      errors.add(:direction, "does not match effective policy") unless valid
    end

    def lifecycle_shape
      valid = case state
      when "pending", "scheduled"
        submitted_at.nil? && applied_at.nil? && failed_at.nil? && failure_category.nil?
      when "submitted"
        submitted_at.present? && applied_at.nil? && failed_at.nil? && failure_category.nil?
      when "applied"
        submitted_at.present? && applied_at.present? && failed_at.nil? && failure_category.nil?
      when "failed"
        applied_at.nil? && failed_at.present? && failure_category.present?
      when "canceled"
        applied_at.nil? && failed_at.nil? && failure_category.nil?
      else
        false
      end
      errors.add(:state, "does not match plan-change lifecycle") unless valid
    end
  end
end
