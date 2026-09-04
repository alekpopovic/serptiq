# frozen_string_literal: true

require "test_helper"

class AuditConsistencyReportTest < ActiveSupport::TestCase
  setup do
    @owner = create_organization_for(slug: "audit-consistency-owner")
    @foreign = create_organization_for(slug: "audit-consistency-foreign")
  end

  test "reports no issues for normal known targets" do
    Auditing::Public.record!(
      organization_id: @owner.organization.id,
      actor_membership_id: @owner.membership.id,
      action: "membership.reviewed",
      target_type: "Membership",
      target_id: @owner.membership.id,
      result: "succeeded"
    )

    assert_empty Auditing::Public.consistency_issues
  end

  test "reports generic target cross-tenant and orphan relationships" do
    cross_tenant = Auditing::Public.record!(
      organization_id: @owner.organization.id,
      actor_membership_id: @owner.membership.id,
      action: "membership.reviewed",
      target_type: "Membership",
      target_id: @foreign.membership.id,
      result: "denied"
    )
    orphan = Auditing::Public.record!(
      organization_id: @owner.organization.id,
      actor_membership_id: @owner.membership.id,
      action: "team.reviewed",
      target_type: "Team",
      target_id: SecureRandom.uuid,
      result: "denied"
    )

    issues = Auditing::Public.consistency_issues
    assert_includes issues,
      Auditing::ConsistencyIssue.new(audit_event_id: cross_tenant.id, reason_code: "target_cross_tenant")
    assert_includes issues,
      Auditing::ConsistencyIssue.new(audit_event_id: orphan.id, reason_code: "target_orphan")
  end

  test "reports a project target from another tenant" do
    Authorization::Public.sync_catalog
    enable_project_limit(@foreign)
    project = create_project_for(@foreign, slug: "foreign-audit-project")
    event = Auditing::Public.record!(
      organization_id: @owner.organization.id,
      actor_membership_id: @owner.membership.id,
      action: "project.reviewed",
      target_type: "Project",
      target_id: project.id,
      result: "denied"
    )

    assert_includes Auditing::Public.consistency_issues,
      Auditing::ConsistencyIssue.new(audit_event_id: event.id, reason_code: "target_cross_tenant")
  end
end
