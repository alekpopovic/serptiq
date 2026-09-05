# frozen_string_literal: true

module Administration
  class DeletionStageExecution < ApplicationRecord
    self.table_name = "resource_deletion_stage_executions"

    STATES = %w[pending running retryable completed].freeze

    belongs_to :workflow, class_name: "Administration::DeletionWorkflow",
      foreign_key: :resource_deletion_workflow_id, inverse_of: :stage_executions

    validates :organization_id, presence: true
    validates :stage, inclusion: { in: DeletionWorkflow::STAGES }
    validates :position, numericality: { only_integer: true, in: 0...DeletionWorkflow::STAGES.length }
    validates :state, inclusion: { in: STATES }
    validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :cursor, length: { maximum: 512 }, allow_nil: true
  end
end
