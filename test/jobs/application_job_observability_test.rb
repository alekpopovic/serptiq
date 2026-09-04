# frozen_string_literal: true

require "test_helper"

class ObservabilityProbeJob < ApplicationJob
  class_attribute :snapshots, default: []

  def perform
    self.class.snapshots << Shared::Observability::Context.snapshot
  end
end

class ObservabilityFailingJob < ApplicationJob
  def perform
    cause = IOError.new("synthetic upstream failure")
    raise RuntimeError.new("synthetic job failure"), cause: cause
  end
end

class ApplicationJobObservabilityTest < ActiveSupport::TestCase
  setup do
    ObservabilityProbeJob.snapshots = []
    Shared::Observability::Context.reset
  end

  teardown { Shared::Observability::Context.reset }

  test "attaches a job context and clears stale context after every execution" do
    Shared::Observability::Context.request_id = "stale-request"

    first_job = ObservabilityProbeJob.new
    second_job = ObservabilityProbeJob.new
    first_job.perform_now
    second_job.perform_now

    assert_equal 2, ObservabilityProbeJob.snapshots.length
    assert_nil ObservabilityProbeJob.snapshots.first["request_id"]
    assert_equal first_job.job_id, ObservabilityProbeJob.snapshots.first.fetch("job_id")
    assert_equal second_job.job_id, ObservabilityProbeJob.snapshots.second.fetch("job_id")
    assert_empty Shared::Observability::Context.snapshot
  end

  test "serializes request trace correlation for execution in another process" do
    trace_id = "c" * 32
    adapter = ActiveJob::QueueAdapters::TestAdapter.new
    previous_adapter = ObservabilityProbeJob.queue_adapter
    ObservabilityProbeJob.queue_adapter = adapter

    Shared::Observability::Context.set(trace_id: trace_id) do
      ObservabilityProbeJob.perform_later
    end
    payload = adapter.enqueued_jobs.fetch(0)
    restored = ActiveJob::Base.deserialize(payload)
    restored.perform_now

    assert_equal trace_id, payload.fetch(ApplicationJob::TRACE_ID_SERIALIZATION_KEY)
    assert_equal trace_id, restored.observability_trace_id
    assert_equal trace_id, ObservabilityProbeJob.snapshots.last.fetch("trace_id")
    assert_empty Shared::Observability::Context.snapshot
  ensure
    ObservabilityProbeJob.queue_adapter = previous_adapter if previous_adapter
  end

  test "emits a correlated failure without error messages and clears context" do
    logger = Class.new do
      attr_reader :entries

      def initialize
        @entries = []
      end

      def error(message)
        entries << message
      end
    end.new
    previous_emitter = Shared::Observability.emitter
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: logger)
    job = ObservabilityFailingJob.new

    assert_raises(RuntimeError) { job.perform_now }
    event = JSON.parse(logger.entries.fetch(0))
    assert_equal "job.execution_failed", event.fetch("event_name")
    assert_equal job.job_id, event.fetch("job_id")
    assert_equal "RuntimeError", event.fetch("exception_class")
    assert_equal [ "IOError" ], event.fetch("cause_classes")
    refute_match(/synthetic .* failure/, JSON.generate(event))
    assert_empty Shared::Observability::Context.snapshot
  ensure
    Shared::Observability.emitter = previous_emitter if previous_emitter
  end
end
