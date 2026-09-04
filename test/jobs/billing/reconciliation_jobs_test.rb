# frozen_string_literal: true

require "test_helper"

class BillingReconciliationJobsTest < ActiveSupport::TestCase
  class RecordingReconciler
    attr_reader :ids

    def initialize
      @ids = []
    end

    def call(reconciliation_run_id:)
      ids << reconciliation_run_id
    end
  end

  class RecordingScheduler
    attr_reader :calls

    def initialize
      @calls = 0
    end

    def call
      @calls += 1
    end
  end

  setup do
    @previous_reconciler = Billing::ReconciliationJob.reconciler_builder
    @previous_scheduler = Billing::ReconciliationSweepJob.scheduler_builder
  end

  teardown do
    Billing::ReconciliationJob.reconciler_builder = @previous_reconciler
    Billing::ReconciliationSweepJob.scheduler_builder = @previous_scheduler
  end

  test "reconciliation job passes only a durable run identifier and remains redelivery safe" do
    recorder = RecordingReconciler.new
    Billing::ReconciliationJob.reconciler_builder = -> { recorder }
    run_id = SecureRandom.uuid

    2.times { Billing::ReconciliationJob.perform_now(reconciliation_run_id: run_id) }

    assert_equal [ run_id, run_id ], recorder.ids
  end

  test "scheduled sweep delegates without tenant context or serialized records" do
    scheduler = RecordingScheduler.new
    Billing::ReconciliationSweepJob.scheduler_builder = -> { scheduler }

    Billing::ReconciliationSweepJob.perform_now

    assert_equal 1, scheduler.calls
  end
end
