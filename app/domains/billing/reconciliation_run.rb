# frozen_string_literal: true

module Billing
  class ReconciliationRun < ApplicationRecord
    self.table_name = "billing_reconciliation_runs"

    SOURCES = %w[scheduled targeted].freeze
    STATES = %w[queued running matched repaired ambiguous missing retryable failed].freeze
    ACTIVE_STATES = %w[queued running retryable].freeze
    TERMINAL_STATES = STATES - ACTIVE_STATES

    belongs_to :subscription, class_name: "Billing::Subscription"
    belongs_to :requested_by_user, class_name: "Identity::User", optional: true

    validates :organization_id, :subscription_id, :provider, :environment, :requested_at, presence: true
    validates :provider, format: { with: ValueNormalization::PROVIDER_PATTERN }
    validates :environment, inclusion: { in: PlanProviderMapping::ENVIRONMENTS }
    validates :source, inclusion: { in: SOURCES }
    validates :state, inclusion: { in: STATES }
    validates :attempt_count, numericality: { only_integer: true, in: 0..5 }
    validates :failure_category, format: { with: ValueNormalization::KEY_PATTERN }, allow_nil: true
    validate :identifier_shapes
    validate :payload_shapes
    validate :requester_shape
    validate :lifecycle_shape
    validate :enqueue_order

    scope :active, -> { where(state: ACTIVE_STATES) }
    scope :recent_first, -> { order(requested_at: :desc, id: :desc) }

    def summary
      ReconciliationSummary.new(
        id: id,
        organization_id: organization_id,
        subscription_id: subscription_id,
        provider: provider,
        environment: environment,
        source: source,
        state: state,
        difference_fields: difference_fields,
        failure_category: failure_category,
        requested_at: requested_at,
        completed_at: completed_at,
        next_attempt_at: next_attempt_at,
        attempt_count: attempt_count
      )
    end

    def terminal?
      TERMINAL_STATES.include?(state)
    end

    def provider_event_id
      "reconciliation-#{id}"
    end

    def event_type
      "subscription.updated"
    end

    private

    def identifier_shapes
      %i[organization_id subscription_id].each do |attribute|
        errors.add(attribute, "is invalid") unless Shared::Public.application_uuid?(public_send(attribute))
      end
      if requested_by_user_id && !Shared::Public.application_uuid?(requested_by_user_id)
        errors.add(:requested_by_user_id, "is invalid")
      end
    end

    def payload_shapes
      valid_snapshot = provider_snapshot.is_a?(Hash) && JSON.generate(provider_snapshot).bytesize <= 8.kilobytes
      valid_differences = difference_fields.is_a?(Array) && difference_fields.length <= 24 &&
        difference_fields.all? { |field| ValueNormalization::KEY_PATTERN.match?(field.to_s) } &&
        JSON.generate(difference_fields).bytesize <= 2.kilobytes
      errors.add(:provider_snapshot, "must be a bounded object") unless valid_snapshot
      errors.add(:difference_fields, "must be a bounded key list") unless valid_differences
    end

    def requester_shape
      valid = (source == "scheduled" && requested_by_user_id.nil?) ||
        (source == "targeted" && requested_by_user_id.present?)
      errors.add(:requested_by_user_id, "does not match source") unless valid
    end

    def lifecycle_shape
      valid = case state
      when "queued"
        attempt_count.zero? && started_at.nil? && completed_at.nil? && next_attempt_at.nil? && failure_category.nil?
      when "running"
        attempt_count.positive? && started_at.present? && completed_at.nil? && next_attempt_at.nil? &&
          failure_category.nil?
      when "retryable"
        attempt_count.positive? && started_at.present? && completed_at.nil? && next_attempt_at.present? &&
          failure_category.present?
      when "matched", "repaired", "ambiguous"
        attempt_count.positive? && started_at.present? && completed_at.present? && next_attempt_at.nil? &&
          failure_category.nil?
      when "missing", "failed"
        attempt_count.positive? && started_at.present? && completed_at.present? && next_attempt_at.nil? &&
          failure_category.present?
      else
        false
      end
      errors.add(:state, "does not match reconciliation lifecycle") unless valid
    end

    def enqueue_order
      return unless enqueued_at && requested_at && enqueued_at < requested_at

      errors.add(:enqueued_at, "cannot precede request")
    end
  end
end
