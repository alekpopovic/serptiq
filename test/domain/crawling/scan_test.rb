# frozen_string_literal: true

require "test_helper"

class CrawlingScanTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "scan-domain")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    enable_crawl_policy(@owner)
    @project = create_project_for(@owner, slug: "scan-domain-project")
    @property = create_property_for(@owner, project: @project)
    @environment = @property.environments.sole
    @now = Time.utc(2026, 9, 5, 8)
  end

  test "creates a requested scan with canonical immutable snapshots and append-only evidence" do
    scan = create_scan_for(
      @owner,
      project: @project,
      property: @property,
      environment: @environment,
      at: @now,
      settings_snapshot: { robots_behavior: "respect", max_urls: 20 }
    )

    assert_equal "requested", scan.status
    assert_equal "membership", scan.initiator_type
    assert_equal @owner.membership.id, scan.initiated_by_membership_id
    assert_equal({ "max_urls" => 20, "robots_behavior" => "respect" }, scan.settings_snapshot)
    assert_equal Digest::SHA256.hexdigest(JSON.generate(scan.settings_snapshot.sort.to_h)), scan.settings_digest
    assert_equal 1, scan.progress_sequence
    event = scan.events.sole
    assert_equal "scan.requested", event.event_type
    assert_equal scan.counters, event.counters
    assert Auditing::AuditEvent.exists?(action: "scan.requested", target_id: scan.id)
    assert Shared::Events::OutboxEvent.exists?(event_type: "scan.requested", aggregate_id: scan.id)

    error = assert_raises(Crawling::Invalid) do
      create_scan_for(
        @owner,
        project: @project,
        property: @property,
        settings_snapshot: { "access_token" => "must-not-be-stored" }
      )
    end
    assert_equal "scan_snapshot_invalid", error.reason_code
  end

  test "state transition matrix permits only explicit forward commands and never reopens terminal state" do
    expected = {
      "admit" => [ "requested", "admitted" ],
      "queue" => [ "admitted", "queued" ],
      "start" => [ "queued", "running" ],
      "acknowledge_cancel" => [ "cancel_requested", "canceled" ],
      "complete" => [ "running", "completed" ],
      "complete_partially" => [ "running", "partially_completed" ]
    }
    expected.each do |command, (from, to)|
      assert_equal to, Crawling::ScanTransitionMatrix.target(status: from, command: command)
    end
    Crawling::Scan::TERMINAL_STATUSES.each do |terminal|
      Crawling::ScanTransitionMatrix.commands.each do |command|
        refute Crawling::ScanTransitionMatrix.allowed?(status: terminal, command: command)
      end
    end

    scan = create_scan_for(@owner, project: @project, property: @property, at: @now)
    scan = transition_scan(scan, "admit", at: @now + 1.second)
    scan = transition_scan(scan, "queue", at: @now + 2.seconds)
    scan = transition_scan(scan, "start", at: @now + 3.seconds)
    scan = transition_scan(scan, "complete", at: @now + 4.seconds)

    assert_equal "completed", scan.status
    assert_equal @now + 4.seconds, scan.completed_at
    assert_equal %w[scan.requested scan.admitted scan.queued scan.started scan.completed],
      scan.events.order(:sequence).pluck(:event_type)
    assert_equal 1, Auditing::AuditEvent.where(action: "scan.started", target_id: scan.id).count
    assert_equal 1, Auditing::AuditEvent.where(action: "scan.completed", target_id: scan.id).count

    assert_no_difference "Crawling::ScanEvent.count" do
      assert_equal scan.id, transition_scan(scan, "complete", at: @now + 5.seconds).id
    end
    error = assert_raises(Crawling::Conflict) do
      transition_scan(scan, "start", at: @now + 6.seconds)
    end
    assert_equal "scan_transition_invalid", error.reason_code
  end

  test "failure stores only a safe category and conflicting retries do not change evidence" do
    scan = create_scan_for(@owner, project: @project, property: @property, at: @now)
    scan = run_scan_to(scan, "running", at: @now + 1.second)

    invalid = assert_raises(Crawling::Conflict) do
      transition_scan(scan, "fail", failure_category: "RuntimeError: credential=hidden")
    end
    assert_equal "scan_failure_category_invalid", invalid.reason_code

    failed = transition_scan(scan, "fail", failure_category: "crawler_timeout", at: @now + 5.seconds)
    assert_equal "failed", failed.status
    assert_equal "crawler_timeout", failed.failure_category
    assert_equal "crawler_timeout", failed.events.last.failure_category

    assert_no_difference "Crawling::ScanEvent.count" do
      assert_equal failed.id, transition_scan(failed, "fail", failure_category: "crawler_timeout").id
    end
    conflict = assert_raises(Crawling::Conflict) do
      transition_scan(failed, "fail", failure_category: "network_failure")
    end
    assert_equal "scan_transition_invalid", conflict.reason_code
  end

  test "model rejects a digest that does not describe its immutable snapshot" do
    scan = create_scan_for(@owner, project: @project, property: @property, at: @now)
    scan.settings_digest = "0" * 64

    refute scan.valid?
    assert_includes scan.errors[:settings_digest], "does not match the snapshot"
  end

  test "batch progress is consistent idempotent and separate from terminal business outcome" do
    scan = create_scan_for(@owner, project: @project, property: @property, at: @now)
    scan = run_scan_to(scan, "running", at: @now + 1.second)
    counters = Crawling::ScanCounters.new(
      targets_count: 2,
      urls_discovered_count: 12,
      urls_queued_count: 2,
      urls_running_count: 1,
      urls_processed_count: 9,
      urls_succeeded_count: 6,
      urls_failed_count: 2,
      urls_skipped_count: 1,
      findings_count: 4
    )

    progressed = Crawling::Public.record_scan_progress(
      organization_id: scan.organization_id,
      scan_id: scan.id,
      counters: counters,
      checkpoint_key: "worker-batch-0001",
      clock: -> { @now + 5.seconds }
    )

    assert_equal "running", progressed.status
    assert_equal 2, progressed.urls_failed_count
    assert_equal counters, progressed.counters
    assert_no_difference "Crawling::ScanEvent.count" do
      retry_result = Crawling::Public.record_scan_progress(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        counters: counters,
        checkpoint_key: "worker-batch-0001"
      )
      assert_equal progressed.id, retry_result.id
    end

    conflicting = counters.to_h.merge(findings_count: 5)
    assert_raises(Crawling::Conflict) do
      Crawling::Public.record_scan_progress(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        counters: conflicting,
        checkpoint_key: "worker-batch-0001"
      )
    end
    regressed = counters.to_h.merge(urls_discovered_count: 11)
    assert_raises(Crawling::Conflict) do
      Crawling::Public.record_scan_progress(
        organization_id: scan.organization_id,
        scan_id: scan.id,
        counters: regressed,
        checkpoint_key: "worker-batch-0002"
      )
    end

    terminal_counters = counters.to_h.merge(urls_discovered_count: 12, urls_queued_count: 0,
      urls_running_count: 0, urls_processed_count: 12, urls_succeeded_count: 8,
      urls_failed_count: 3, urls_skipped_count: 1)
    progressed = Crawling::Public.record_scan_progress(
      organization_id: scan.organization_id,
      scan_id: scan.id,
      counters: terminal_counters,
      checkpoint_key: "worker-batch-0003",
      clock: -> { @now + 6.seconds }
    )
    completed = transition_scan(progressed, "complete_partially", at: @now + 7.seconds)
    assert_equal "partially_completed", completed.status
    assert_equal 3, completed.urls_failed_count
  end

  test "user cancellation distinguishes cooperative and immediate outcomes and emits safe events" do
    queued = create_scan_for(@owner, project: @project, property: @property, at: @now)
    queued = run_scan_to(queued, "queued", at: @now + 1.second)

    requested = Crawling::Public.request_scan_cancellation(
      actor_membership: @owner.membership,
      project_id: @project.id,
      scan_id: queued.id,
      clock: -> { @now + 4.seconds }
    )
    assert_equal "cancel_requested", requested.status
    assert_nil requested.canceled_at
    canceled = transition_scan(requested, "acknowledge_cancel", at: @now + 5.seconds)
    assert_equal "canceled", canceled.status
    assert Auditing::AuditEvent.exists?(action: "scan.cancel_requested", target_id: queued.id)
    assert Shared::Events::OutboxEvent.exists?(event_type: "scan.canceled", aggregate_id: queued.id)

    pending = create_scan_for(@owner, project: @project, property: @property, at: @now + 10.seconds)
    pending = Crawling::Public.request_scan_cancellation(
      actor_membership: @owner.membership,
      project_id: @project.id,
      scan_id: pending.id,
      clock: -> { @now + 11.seconds }
    )
    assert_equal "canceled", pending.status
    assert_equal pending.cancel_requested_at, pending.canceled_at
  end

  test "baseline and read models are exact-target and cross-tenant safe" do
    baseline = create_scan_for(@owner, project: @project, property: @property, at: @now)
    baseline = run_scan_to(baseline, "completed", at: @now + 1.second)
    candidate = create_scan_for(
      @owner,
      project: @project,
      property: @property,
      at: @now + 10.seconds,
      baseline_scan_id: baseline.id,
      release_id: SecureRandom.uuid
    )
    detail = Crawling::Public.scan_details(
      actor_membership: @owner.membership,
      project_id: @project.id,
      scan_id: candidate.id
    )
    assert_equal baseline.id, detail.baseline_scan_id
    assert_equal 1, detail.events.length

    foreign = create_organization_for(slug: "scan-domain-foreign")
    enable_project_limit(foreign)
    foreign_project = create_project_for(foreign, slug: "scan-domain-foreign-project")
    assert_raises(Crawling::AccessDenied) do
      Crawling::Public.scan_page(
        actor_membership: foreign.membership,
        project_id: @project.id
      )
    end
    assert_raises(Crawling::AccessDenied) do
      Crawling::Public.scan_details(
        actor_membership: foreign.membership,
        project_id: foreign_project.id,
        scan_id: candidate.id
      )
    end
  end

  test "policy snapshot is bound to an already persisted exact scan" do
    Crawling::Public.configure_policy(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      attributes: valid_crawl_policy_attributes(origin: @environment.origin)
    )
    scan = create_scan_for(@owner, project: @project, property: @property)

    snapshot = Crawling::Public.snapshot_for_scan(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      scan_id: scan.id
    )

    assert_equal scan.id, snapshot.scan_id
    assert_equal scan.environment_id, snapshot.environment_id
  end
end
