# frozen_string_literal: true

require "json"
require "test_helper"

class AuthorizationDecisionTest < ActiveSupport::TestCase
  class CaptureLogger
    attr_reader :entries

    def initialize
      @entries = []
    end

    %i[debug info warn error fatal].each do |severity|
      define_method(severity) { |message| entries << [ severity, message ] }
    end
  end

  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "authorization-decision")
    @member = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Decision Member")
    )
    @team = Tenancy::Public.create_team(actor_membership: @owner.membership, name: "Decision Team")
    Tenancy::Public.add_team_member(
      actor_membership: @owner.membership, team_id: @team.id, membership_id: @member.id
    )
    @project_id = SecureRandom.uuid
    @other_project_id = SecureRandom.uuid
    @property_id = SecureRandom.uuid
    register_scope("Project", @project_id)
    register_scope("Project", @other_project_id)
    register_scope("Property", @property_id, project_id: @project_id)
    @previous_emitter = Shared::Observability.emitter
    @logger = CaptureLogger.new
    Shared::Observability.emitter = Shared::Observability::EventEmitter.new(logger: @logger)
  end

  teardown { Shared::Observability.emitter = @previous_emitter }

  test "truth table resolves direct team and ancestor grants without upward or sideways flow" do
    organization_grant = assign("viewer", "Membership", @member.id, "Organization", @owner.organization.id)
    project_grant = assign("analyst", "Team", @team.id, "Project", @project_id)
    property_grant = assign("content_editor", "Membership", @member.id, "Property", @property_id)

    assert_decision true, "organization.read", reason: "permission_granted",
      sources: [ organization_grant.id ]
    assert_decision true, "projects.read", project: @project_id,
      sources: [ organization_grant.id, project_grant.id ]
    assert_decision true, "usage.read", project: @project_id, sources: [ project_grant.id ]
    assert_decision true, "findings.triage", project: @project_id, property: @property_id,
      sources: [ property_grant.id ]
    assert_decision false, "findings.triage", project: @project_id, reason: "permission_missing"
    assert_decision false, "findings.triage", project: @other_project_id, reason: "permission_missing"
    assert_decision false, "organization.read", project: @project_id, reason: "scope_mismatch"
    assert_decision false, "projects.read", reason: "scope_mismatch"
  end

  test "fails closed for anonymous foreign inactive archived unknown and unavailable resources" do
    assign("viewer", "Membership", @member.id, "Project", @project_id)
    assign("analyst", "Team", @team.id, "Project", @project_id)
    anonymous = decision("projects.read", project: @project_id, actor: nil)
    assert anonymous.deny?
    assert_equal "not_authenticated", anonymous.reason_code

    foreign = create_organization_for(slug: "authorization-decision-foreign")
    cross_tenant = Authorization::Decision.call(
      actor_membership: @member,
      permission_key: "projects.read",
      organization: foreign.organization,
      project: @project_id
    )
    assert cross_tenant.deny?
    assert_equal "scope_mismatch", cross_tenant.reason_code

    unknown = decision("invented.permission", project: @project_id)
    assert unknown.deny?
    assert_equal "unknown_permission", unknown.reason_code

    mismatched = decision(
      "projects.read",
      project: @project_id,
      resource: Authorization::ResourceContext.new(
        id: SecureRandom.uuid, type: "Scan", organization_id: foreign.organization.id,
        scope_type: "Project", scope_id: @project_id
      )
    )
    assert_equal "scope_mismatch", mismatched.reason_code
    unavailable = decision(
      "projects.read",
      project: @project_id,
      resource: Authorization::ResourceContext.new(
        id: SecureRandom.uuid, type: "Scan", organization_id: @owner.organization.id,
        scope_type: "Project", scope_id: @project_id, available: false
      )
    )
    assert_equal "resource_unavailable", unavailable.reason_code

    wrong_parent = decision("projects.read", project: @other_project_id, property: @property_id)
    assert_equal "scope_mismatch", wrong_parent.reason_code

    assert decision("usage.read", project: @project_id).allow?
    Tenancy::Public.archive_team(actor_membership: @owner.membership, team_id: @team.id)
    assert_equal "permission_missing", decision("usage.read", project: @project_id).reason_code

    register_scope("Project", @project_id, status: "archived")
    assert_equal "resource_unavailable", decision("projects.read", project: @project_id).reason_code

    Tenancy::Public.change_membership_status(
      actor_membership: @owner.membership, target_membership_id: @member.id, operation: "suspend"
    )
    assert_equal "membership_inactive", decision("projects.read", project: @project_id).reason_code
  end

  test "owner-only permissions ignore custom grants while grant management follows effective permissions" do
    admin = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Decision Admin")
    )
    assign("organization_admin", "Membership", admin.id, "Organization", @owner.organization.id)
    assert decision("roles.assign", actor: admin).allow?

    protected_role = Authorization::Role.create!(
      organization_id: @owner.organization.id,
      key: "unsafe_transfer",
      name: "Unsafe Transfer",
      system: false,
      mutable: true,
      assignable_scopes: [ "organization" ]
    )
    Authorization::RolePermission.create!(
      role: protected_role,
      permission: Authorization::Permission.find_by!(key: "organization.transfer")
    )
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: admin.id,
      role_id: protected_role.id,
      scope_type: "Organization",
      scope_id: @owner.organization.id
    )

    denied = decision("organization.transfer", actor: admin)
    assert denied.deny?
    assert_equal "owner_permission_required", denied.reason_code
    owner_decision = decision("organization.transfer", actor: @owner.membership)
    assert owner_decision.allow?
    assert_equal [ "organization_ownership" ], owner_decision.sources
  end

  test "privilege revocation is visible to the next decision without a stale cache" do
    assignment = assign("viewer", "Membership", @member.id, "Project", @project_id)
    assert decision("projects.read", project: @project_id).allow?

    Authorization::Public.revoke_role(actor_membership: @owner.membership, assignment_id: assignment.id)

    result = decision("projects.read", project: @project_id)
    assert result.deny?
    assert_equal "permission_missing", result.reason_code
  end

  test "high-risk denial emits bounded hashed audit metadata and the adapter raises the decision" do
    result = decision("projects.delete", project: @project_id)
    assert result.deny?
    event = parsed_events.find { |row| row["event_name"] == "authorization.denied_high_risk" }
    assert event
    assert_equal "projects.delete", event.fetch("operation")
    assert_equal "permission_missing", event.fetch("reason_code")
    assert_match(/\A[0-9a-f]{24}\z/, event.fetch("actor_id_hash"))
    assert_match(/\A[0-9a-f]{24}\z/, event.fetch("scope_id_hash"))
    refute_includes event.to_json, @member.id
    refute_includes event.to_json, @project_id

    adapter = Authorization::Public.policy(
      actor_membership: @member, organization: @owner.organization
    )
    error = assert_raises(Authorization::AccessDenied) do
      adapter.authorize!(permission_key: "projects.delete", project: @project_id)
    end
    assert_equal result.reason_code, error.decision.reason_code
  end

  test "representative direct and multi-team decision has a constant bounded query count" do
    assign("viewer", "Membership", @member.id, "Project", @project_id)
    8.times do |index|
      team = Tenancy::Public.create_team(
        actor_membership: @owner.membership, name: "Performance Team #{index}"
      )
      Tenancy::Public.add_team_member(
        actor_membership: @owner.membership, team_id: team.id, membership_id: @member.id
      )
      assign("analyst", "Team", team.id, "Project", @project_id)
    end
    decision("usage.read", project: @project_id)

    queries = capture_selects { @performance_result = decision("usage.read", project: @project_id) }

    assert @performance_result.allow?
    assert_operator queries.length, :<=, 15, queries.join("\n")
    assert_equal 1, queries.count { |sql| sql.include?('FROM "role_assignments"') }
  end

  private

  def decision(permission, actor: @member, project: nil, property: nil, resource: nil)
    Authorization::Decision.call(
      actor_membership: actor,
      permission_key: permission,
      organization: @owner.organization,
      project: project,
      property: property,
      resource: resource
    )
  end

  def assert_decision(expected, permission, reason: nil, sources: nil, **scope)
    result = decision(permission, **scope)
    assert_equal expected, result.allow?, "#{permission} at #{scope.inspect}: #{result.reason_code}"
    assert_equal reason, result.reason_code if reason
    assert_equal sources.sort, result.sources if sources
  end

  def register_scope(type, id, project_id: nil, status: "active")
    Authorization::Public.register_scope(
      organization_id: @owner.organization.id,
      scope_type: type,
      scope_id: id,
      project_id: project_id,
      status: status
    )
  end

  def assign(role_key, grantee_type, grantee_id, scope_type, scope_id)
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: grantee_type,
      grantee_id: grantee_id,
      role_id: Authorization::Role.find_by!(system: true, key: role_key).id,
      scope_type: scope_type,
      scope_id: scope_id
    )
  end

  def capture_selects
    queries = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      sql = payload.fetch(:sql)
      queries << sql if sql.start_with?("SELECT") && payload[:name] != "SCHEMA"
    end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    queries
  end

  def parsed_events
    @logger.entries.map(&:last).filter_map do |line|
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end
  end
end
