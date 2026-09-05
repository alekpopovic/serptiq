# frozen_string_literal: true

module Administration
  class DeletionWorkflow < ApplicationRecord
    self.table_name = "resource_deletion_workflows"

    TARGET_TYPES = %w[Project Property].freeze
    STATES = %w[holding running retryable completed canceled].freeze
    STAGES = %w[
      cancel_active_work integrations scans_and_findings reports object_artifacts
      api_keys_and_webhooks aggregate_records
    ].freeze
    ERROR_PATTERN = /\A[a-z][a-z0-9_]{0,63}\z/

    has_many :stage_executions, class_name: "Administration::DeletionStageExecution",
      foreign_key: :resource_deletion_workflow_id, inverse_of: :workflow,
      dependent: :delete_all

    validates :organization_id, :target_id, :project_id, :requested_by_membership_id,
      :requested_at, :hold_until, presence: true
    validates :target_type, inclusion: { in: TARGET_TYPES }
    validates :state, inclusion: { in: STATES }
    validates :current_stage, inclusion: { in: STAGES }, allow_nil: true
    validates :last_error_category, format: { with: ERROR_PATTERN }, allow_nil: true
    validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :target_shape
    validate :hold_follows_request

    scope :active, -> { where(state: %w[holding running retryable]) }

    def holding?
      state == "holding"
    end

    def running?
      state == "running"
    end

    def retryable?
      state == "retryable"
    end

    def completed?
      state == "completed"
    end

    def canceled?
      state == "canceled"
    end

    def due?(at: Time.current)
      holding? ? hold_until <= at : retryable? && next_attempt_at <= at
    end

    def cancelable?(at: Time.current)
      holding? && at < hold_until
    end

    private

    def target_shape
      valid = if target_type == "Project"
        target_id == project_id && property_id.nil?
      elsif target_type == "Property"
        target_id == property_id && property_id.present?
      end
      errors.add(:target_id, "does not match resource hierarchy") unless valid
    end

    def hold_follows_request
      return if requested_at.blank? || hold_until.blank? || hold_until > requested_at

      errors.add(:hold_until, "must follow the deletion request")
    end
  end
end
