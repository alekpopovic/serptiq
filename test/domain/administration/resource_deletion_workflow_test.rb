# frozen_string_literal: true

require "test_helper"

class AdministrationResourceDeletionWorkflowTest < ActiveSupport::TestCase
  class ReconciledObjectStore < Administration::ObjectStore
    attr_reader :delete_calls, :reconciliation_calls

    def initialize(remaining: [])
      @remaining = remaining.dup
      @delete_calls = []
      @reconciliation_calls = []
    end

    def delete_prefix(prefix:, cursor: nil)
      @delete_calls << [ prefix, cursor ]
      DeleteResult.new(completed: true)
    end

    def objects_remaining?(prefix:)
      @reconciliation_calls << prefix
      @remaining.shift || false
    end
  end

  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "deletion-workflow")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    enable_crawl_policy(@owner)
    @project = create_project_for(@owner, slug: "delete-project")
    @property = create_property_for(
      @owner,
      project: @project,
      display_name: "Deletion property",
      configuration: { origin: "https://delete.example.com" }
    )
    @environment = @property.environments.sole
    Crawling::Public.configure_policy(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: @environment.id,
      attributes: valid_crawl_policy_attributes(origin: @environment.origin)
    )
    @scan = create_scan_for(
      @owner, project: @project, property: @property, environment: @environment
    )
    frontier_entry = Crawling::FrontierEntry.new(
      url: "https://delete.example.com/",
      depth: 0,
      discovery_source: "seed"
    )
    @crawl_url = Crawling::CrawlUrl.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      **frontier_entry.to_h,
      state: "pending",
      attempts: 0,
      maximum_attempts: 3,
      next_attempt_at: Time.current
    )
    @robots_snapshot = Crawling::RobotsSnapshot.create!(
      organization_id: @scan.organization_id,
      project_id: @scan.project_id,
      property_id: @scan.property_id,
      environment_id: @scan.environment_id,
      scan_id: @scan.id,
      origin: @environment.origin,
      origin_digest: Digest::SHA256.hexdigest(@environment.origin),
      source_url: "#{@environment.origin}/robots.txt",
      final_url: "#{@environment.origin}/robots.txt",
      retrieval_status: "fetched",
      http_status: 200,
      retrieved_at: Time.current,
      artifact_sha256: Digest::SHA256.hexdigest(""),
      parser_version: 1,
      groups: [],
      sitemap_urls: [],
      warnings: [],
      created_at: Time.current
    )
  end

  test "project hold stops admission, signals prior work and deletes in durable stage order" do
    requested_at = 31.days.ago.change(usec: 0)
    workflow = request_project_deletion(at: requested_at)
    retry_workflow = request_project_deletion(at: requested_at + 1.minute)

    assert_equal workflow.id, retry_workflow.id
    assert_equal 1, Administration::DeletionWorkflow.where(target_id: @project.id).count
    assert workflow.holding?
    assert_equal Administration::DeletionWorkflow::STAGES,
      workflow.stage_executions.order(:position).pluck(:stage)
    assert @project.reload.pending_deletion?
    refute @project.scan_available?
    assert Projects::Public.cancellation_requested?(
      organization_id: @owner.organization.id,
      project_id: @project.id,
      work_started_at: requested_at - 1.minute
    )
    refute Projects::Public.cancellation_requested?(
      organization_id: @owner.organization.id,
      project_id: @project.id,
      work_started_at: requested_at + 1.minute
    )

    store = ReconciledObjectStore.new
    runner = Administration::DeletionStageRunner.new(object_store: store)
    completed = Administration::Public.execute_deletion(
      organization_id: @owner.organization.id,
      workflow_id: workflow.id,
      stage_runner: runner,
      clock: -> { Time.current }
    )

    assert completed.completed?
    assert_equal [ "completed" ], workflow.stage_executions.reload.distinct.pluck(:state)
    refute Projects::Project.exists?(@project.id)
    refute Properties::Property.exists?(@property.id)
    refute Properties::Environment.exists?(@environment.id)
    assert_empty Crawling::PolicySet.where(project_id: @project.id)
    refute Crawling::CrawlUrl.exists?(@crawl_url.id)
    refute Crawling::RobotsSnapshot.exists?(@robots_snapshot.id)
    refute Crawling::Scan.exists?(@scan.id)
    assert_equal [ [ "organizations/#{@owner.organization.id}/projects/#{@project.id}/", nil ] ],
      store.delete_calls
    assert Auditing::TargetTombstone.exists?(target_type: "Project", target_id: @project.id)
    assert Auditing::TargetTombstone.exists?(target_type: "Property", target_id: @property.id)
    assert Auditing::TargetTombstone.exists?(
      target_type: "PropertyEnvironment", target_id: @environment.id
    )
    assert Auditing::TargetTombstone.exists?(target_type: "Scan", target_id: @scan.id)
    assert Auditing::AuditEvent.exists?(action: "data.deletion_completed", target_id: @project.id)
    organization_issues = Auditing::Public.consistency_issues.select do |issue|
      issue.organization_id == @owner.organization.id
    end
    assert_empty organization_issues

    assert_equal completed.id, Administration::Public.execute_deletion(
      organization_id: @owner.organization.id,
      workflow_id: workflow.id,
      stage_runner: runner
    ).id
    assert_equal 1, store.delete_calls.length
  end

  test "object-store reconciliation failure persists progress and resumes without replaying stages" do
    requested_at = 31.days.ago.change(usec: 0)
    workflow = request_project_deletion(at: requested_at)
    store = ReconciledObjectStore.new(remaining: [ true, false ])
    runner = Administration::DeletionStageRunner.new(object_store: store)
    first_attempt_at = Time.current.change(usec: 0)

    assert_raises(Administration::ObjectStoreUnavailable) do
      Administration::Public.execute_deletion(
        organization_id: @owner.organization.id,
        workflow_id: workflow.id,
        stage_runner: runner,
        clock: -> { first_attempt_at }
      )
    end

    workflow.reload
    assert workflow.retryable?
    assert_equal "object_artifacts", workflow.current_stage
    assert_equal "external_provider", workflow.last_error_category
    assert_equal %w[completed completed completed completed retryable pending pending],
      workflow.stage_executions.order(:position).pluck(:state)
    assert Projects::Project.exists?(@project.id)

    completed = Administration::Public.execute_deletion(
      organization_id: @owner.organization.id,
      workflow_id: workflow.id,
      stage_runner: runner,
      clock: -> { first_attempt_at + 16.minutes }
    )

    assert completed.completed?
    assert_equal 2, store.delete_calls.length
    assert_equal 1, workflow.stage_executions.find_by!(stage: "cancel_active_work").attempt_count
    assert_equal 2, workflow.stage_executions.find_by!(stage: "object_artifacts").attempt_count
  end

  test "hold cancellation is authorized, bounded by time and tenant exact" do
    requested_at = Time.current.change(usec: 0)
    workflow = request_project_deletion(at: requested_at)

    canceled = Administration::Public.cancel_resource_deletion(
      actor_membership: @owner.membership,
      target_type: "Project",
      project_id: @project.id,
      clock: -> { requested_at + 1.day }
    )
    assert canceled.canceled?
    assert @project.reload.archived?

    foreign = create_organization_for(slug: "deletion-foreign")
    enable_project_limit(foreign)
    assert_no_difference("Administration::DeletionWorkflow.count") do
      assert_raises(Projects::ProjectAccessDenied) do
        Administration::Public.request_resource_deletion(
          actor_membership: foreign.membership,
          target_type: "Project",
          project_id: @project.id,
          current_session: issue_identity_session(user: foreign.membership.user).session,
          user_id: foreign.membership.user_id
        )
      end
    end

    due = request_project_deletion(at: requested_at + 2.days)
    assert_raises(Administration::DeletionConflict) do
      Administration::Public.cancel_resource_deletion(
        actor_membership: @owner.membership,
        target_type: "Project",
        project_id: @project.id,
        clock: -> { due.hold_until }
      )
    end
  end

  test "project request cancels cancelable child workflows instead of leaving orphan work" do
    now = Time.current.change(usec: 0)
    child = Administration::Public.request_resource_deletion(
      actor_membership: @owner.membership,
      target_type: "Property",
      project_id: @project.id,
      property_id: @property.id,
      current_session: issue_identity_session(user: @owner.membership.user, at: now).session,
      user_id: @owner.membership.user_id,
      clock: -> { now }
    )

    parent = request_project_deletion(at: now + 1.minute)

    assert child.reload.canceled?
    assert @property.reload.archived?
    assert parent.holding?
    assert @project.reload.pending_deletion?
    assert_equal parent.id, Administration::DeletionWorkflow.active.find_by!(
      organization_id: @owner.organization.id,
      project_id: @project.id
    ).id
  end

  private

  def request_project_deletion(at:)
    Administration::Public.request_resource_deletion(
      actor_membership: @owner.membership,
      target_type: "Project",
      project_id: @project.id,
      current_session: issue_identity_session(user: @owner.membership.user, at: at).session,
      user_id: @owner.membership.user_id,
      clock: -> { at }
    )
  end
end
