# frozen_string_literal: true

require "test_helper"

class AdministrationDeletionJobsTest < ActiveJob::TestCase
  setup do
    @original_executor = Administration::DeletionWorkflowJob.executor_builder
    @original_scheduler = Administration::DeletionSweepJob.scheduler_builder
  end

  teardown do
    Administration::DeletionWorkflowJob.executor_builder = @original_executor
    Administration::DeletionSweepJob.scheduler_builder = @original_scheduler
  end

  test "workflow job forwards only the explicit tenant and workflow identifiers" do
    calls = []
    executor = Object.new
    executor.define_singleton_method(:call) { |**attributes| calls << attributes }
    Administration::DeletionWorkflowJob.executor_builder = -> { executor }

    organization_id = SecureRandom.uuid
    workflow_id = SecureRandom.uuid
    Administration::DeletionWorkflowJob.perform_now(
      organization_id: organization_id,
      workflow_id: workflow_id
    )

    assert_equal [ { organization_id: organization_id, workflow_id: workflow_id } ], calls
  end

  test "sweep job invokes the bounded reconciliation scheduler" do
    calls = 0
    scheduler = Object.new
    scheduler.define_singleton_method(:call) { calls += 1 }
    Administration::DeletionSweepJob.scheduler_builder = -> { scheduler }

    Administration::DeletionSweepJob.perform_now

    assert_equal 1, calls
  end
end
