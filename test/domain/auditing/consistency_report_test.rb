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

  test "reports a property target from another tenant" do
    Authorization::Public.sync_catalog
    enable_project_limit(@foreign)
    enable_property_limits(@foreign)
    project = create_project_for(@foreign, slug: "foreign-audit-property-project")
    property = create_property_for(@foreign, project: project, kind: "android_app")
    event = Auditing::Public.record!(
      organization_id: @owner.organization.id,
      actor_membership_id: @owner.membership.id,
      action: "property.reviewed",
      target_type: "Property",
      target_id: property.id,
      result: "denied"
    )

    assert_includes Auditing::Public.consistency_issues,
      Auditing::ConsistencyIssue.new(audit_event_id: event.id, reason_code: "target_cross_tenant")
  end

  test "reports a property environment target from another tenant" do
    Authorization::Public.sync_catalog
    enable_project_limit(@foreign)
    enable_property_limits(@foreign)
    project = create_project_for(@foreign, slug: "foreign-audit-environment-project")
    property = create_property_for(@foreign, project: project)
    environment = property.environments.sole
    event = Auditing::Public.record!(
      organization_id: @owner.organization.id,
      actor_membership_id: @owner.membership.id,
      action: "property_environment.reviewed",
      target_type: "PropertyEnvironment",
      target_id: environment.id,
      result: "denied"
    )

    assert_includes Auditing::Public.consistency_issues,
      Auditing::ConsistencyIssue.new(audit_event_id: event.id, reason_code: "target_cross_tenant")
  end

  test "reports a domain verification target from another tenant" do
    Authorization::Public.sync_catalog
    enable_project_limit(@foreign)
    enable_property_limits(@foreign)
    project = create_project_for(@foreign, slug: "foreign-audit-verification-project")
    property = create_property_for(@foreign, project: project)
    challenge = Verification::Public.issue_challenge(
      actor_membership: @foreign.membership,
      project_id: project.id,
      property_id: property.id,
      environment_id: property.environments.sole.id,
      method: "dns_txt"
    ).challenge
    event = Auditing::Public.record!(
      organization_id: @owner.organization.id,
      actor_membership_id: @owner.membership.id,
      action: "verification.reviewed",
      target_type: "DomainVerification",
      target_id: challenge.id,
      result: "denied"
    )

    assert_includes Auditing::Public.consistency_issues,
      Auditing::ConsistencyIssue.new(audit_event_id: event.id, reason_code: "target_cross_tenant")
  end
end
