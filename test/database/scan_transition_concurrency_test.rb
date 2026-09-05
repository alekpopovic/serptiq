# frozen_string_literal: true

require "test_helper"

class ScanTransitionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    truncate_records
    Current.reset
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "scan-transition-concurrency")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "scan-transition-project")
    @property = create_property_for(@owner, project: @project)
    lifecycle_started_at = 5.seconds.ago
    @scan = create_scan_for(
      @owner, project: @project, property: @property, at: lifecycle_started_at
    )
    @scan = run_scan_to(@scan, "running", at: lifecycle_started_at + 1.second)
  end

  teardown do
    Current.reset
    truncate_records
  end

  test "PostgreSQL row lock permits only one contradictory terminal transition" do
    ready = Queue.new
    start = Queue.new
    outcomes = Queue.new
    operations = [
      -> { transition("complete") },
      -> { transition("fail", failure_category: "worker_unavailable") }
    ]
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Current.reset
          ready << true
          start.pop
          outcomes << operation.call.status
        rescue Crawling::Conflict => error
          outcomes << error.reason_code
        rescue StandardError => error
          outcomes << "unexpected:#{error.class.name}:#{error.message}"
        ensure
          Current.reset
        end
      end
    end
    operations.length.times { ready.pop }
    operations.length.times { start << true }
    threads.each(&:join)

    results = operations.length.times.map { outcomes.pop }
    assert_equal 1, results.count("scan_transition_invalid"), results.inspect
    assert_equal 1, results.count { |value| value.in?(%w[completed failed]) }, results.inspect
    assert_empty results.grep(/unexpected/)
    assert_equal 1, Crawling::Scan.where(id: @scan.id).terminal.count
    assert_equal 1, Crawling::ScanEvent.where(
      scan_id: @scan.id,
      event_type: %w[scan.completed scan.failed]
    ).count
  end

  private

  def transition(command, **attributes)
    Crawling::Public.transition_scan(
      organization_id: @scan.organization_id,
      scan_id: @scan.id,
      command: command,
      **attributes
    )
  end

  def truncate_records
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE entitlement_definitions, plans, organizations, users, audit_events CASCADE"
    )
  end
end
