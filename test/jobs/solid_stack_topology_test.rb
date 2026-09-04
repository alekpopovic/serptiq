# frozen_string_literal: true

require "test_helper"

class SolidStackTopologyTest < ActiveSupport::TestCase
  class TransientProbeJob < ApplicationJob
    def perform
      raise Shared::JobErrors::TransientInfrastructure, "temporary test failure"
    end
  end

  class TerminalProbeJob < ApplicationJob
    def perform
      raise Shared::JobErrors::SecurityRejected, "terminal test rejection"
    end
  end

  setup do
    SolidQueue::Job.delete_all
    SolidQueue::Process.delete_all
  end

  teardown do
    SolidQueue::Job.delete_all
    SolidQueue::Process.delete_all
  end

  test "every declared queue applies its name and numeric priority to a representative job class" do
    Shared::JobTopology::QUEUES.each do |name, definition|
      job_class = Class.new(ApplicationJob)
      job_class.runs_on(name)
      job = job_class.new

      assert_equal definition.name.to_s, job.queue_name
      assert_equal definition.priority, job.priority
    end

    assert_equal :mail, Rails.application.config.action_mailer.deliver_later_queue_name
  end

  test "worker roles poll only their exact queues and isolate render jobs" do
    expected = Shared::JobTopology::WORKERS.transform_values { |definition| definition.queues.map(&:to_s) }
    assigned_queues = expected.values.flatten

    expected.each do |role, queues|
      configuration = queue_configuration_for(role)
      configured_queues = configuration.fetch("workers").flat_map { |worker| worker.fetch("queues") }

      assert_equal queues, configured_queues, "unexpected queues for #{role}"
    end

    assert_equal Shared::JobTopology::QUEUES.keys.map(&:to_s).sort, assigned_queues.sort
    assert_equal assigned_queues.uniq.sort, assigned_queues.sort
    default_queues = expected.fetch(:worker_default)
    assert_equal [ "render" ], expected.fetch(:worker_render)
    refute_includes default_queues, "render"
    refute_includes default_queues, "crawl"
    assert Shared::JobTopology::WORKERS.fetch(:worker_default).dispatcher
    refute Shared::JobTopology::WORKERS.fetch(:worker_render).dispatcher
  end

  test "worker concurrency is bounded and render remains single threaded" do
    assert_equal({ threads: 1, processes: 2 }, Shared::JobTopology.execution_options(
      :worker_render,
      environment: { "SEARCHOPS_JOB_THREADS" => "1", "SEARCHOPS_JOB_PROCESSES" => "2" }
    ))

    error = assert_raises(ArgumentError) do
      Shared::JobTopology.execution_options(
        :worker_render,
        environment: { "SEARCHOPS_JOB_THREADS" => "2", "SEARCHOPS_JOB_PROCESSES" => "1" }
      )
    end
    assert_includes error.message, "SEARCHOPS_JOB_THREADS must be between 1 and 1"
    assert_raises(ArgumentError) { Shared::JobTopology.worker(:web) }
  end

  test "base retry taxonomy reschedules transient failures and discards terminal failures" do
    assert_nothing_raised { TransientProbeJob.perform_now }

    retry_record = SolidQueue::Job.find_by!(class_name: TransientProbeJob.name)
    assert retry_record.scheduled_execution
    assert_equal "default", retry_record.queue_name
    assert_equal 1, retry_record.arguments.fetch("executions")

    assert_nothing_raised { TerminalProbeJob.perform_now }
    assert_not SolidQueue::Job.exists?(class_name: TerminalProbeJob.name)
  end

  test "smoke job is enqueued claimed and performed through Solid Queue PostgreSQL" do
    active_job = Shared::SolidQueueSmokeJob.perform_later
    queue_job = SolidQueue::Job.find_by!(active_job_id: active_job.job_id)
    process = SolidQueue::Process.create!(
      kind: "Worker",
      last_heartbeat_at: Time.current,
      pid: Process.pid,
      hostname: "test.local",
      metadata: {},
      name: "solid-stack-test-#{SecureRandom.hex(4)}"
    )

    claimed = SolidQueue::ReadyExecution.claim([ "maintenance" ], 1, process.id).sole
    claimed.perform

    assert queue_job.reload.finished?
    assert_not queue_job.ready?
    assert_not queue_job.claimed?
    assert_not queue_job.failed?
  end

  test "cache is bounded disposable and connected to the cache database" do
    cache = ActiveSupport::Cache.lookup_store(:solid_cache_store)
    configuration = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/cache.yml"))

    assert_equal 7.days.to_i, cache.max_age
    assert_equal 256.megabytes, cache.max_size
    assert_equal :job, cache.expiry_method
    assert_equal :maintenance, cache.expiry_queue
    assert_equal "cache", SolidCache::Record.connection_db_config.name
    assert_equal "cache", configuration.dig("staging", "database")
    assert_equal 256.megabytes, configuration.dig("production", "store_options", "max_size")
  end

  test "cable production topology is bounded and test remains isolated" do
    configuration = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/cable.yml"))
    production = configuration.fetch("production")

    assert_equal "solid_cable", production.fetch("adapter")
    assert_equal "cable", production.dig("connects_to", "database", "writing")
    assert_equal "0.1.seconds", production.fetch("polling_interval")
    assert_equal "1.hour", production.fetch("message_retention")
    assert_equal 200, production.fetch("trim_batch_size")
    assert_equal "test", configuration.dig("test", "adapter")
  end

  test "recurring schedule contains only valid maintenance operations" do
    configuration = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml"))
    tasks = configuration.fetch("test")

    assert_equal %w[
      cleanup_expired_authentication_rate_limits
      cleanup_inactive_identity_sessions
      clear_solid_queue_finished_batches
      clear_solid_queue_finished_jobs
      maintain_organization_invitations
      maintain_usage_quota_reservations
    ], tasks.keys.sort
    assert tasks.values.all? { |task| task.fetch("queue") == "maintenance" }
    assert tasks.values.all? { |task| task.fetch("priority") == 50 }
    assert_equal "Identity::SessionCleanupJob.perform_later",
      tasks.fetch("cleanup_inactive_identity_sessions").fetch("command")
    assert_equal "Identity::AuthenticationRateLimitCleanupJob.perform_later",
      tasks.fetch("cleanup_expired_authentication_rate_limits").fetch("command")
    assert_equal "Tenancy::InvitationMaintenanceJob.perform_later",
      tasks.fetch("maintain_organization_invitations").fetch("command")
    assert_equal "Usage::QuotaReservationMaintenanceJob.perform_later",
      tasks.fetch("maintain_usage_quota_reservations").fetch("command")
    assert tasks.slice("clear_solid_queue_finished_batches", "clear_solid_queue_finished_jobs").values.all? do |task|
      task.fetch("command").start_with?("SolidQueue::")
    end
  end

  private

  def queue_configuration_for(role)
    previous_role = ENV["SEARCHOPS_PROCESS_ROLE"]
    ENV["SEARCHOPS_PROCESS_ROLE"] = role.to_s
    ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/queue.yml")).fetch(Rails.env)
  ensure
    ENV["SEARCHOPS_PROCESS_ROLE"] = previous_role
  end
end
