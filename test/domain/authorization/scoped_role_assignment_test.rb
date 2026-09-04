# frozen_string_literal: true

require "json"
require "test_helper"

class AuthorizationScopedRoleAssignmentTest < ActiveSupport::TestCase
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
    @owner = create_organization_for(slug: "scoped-role-assignment")
    @member = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Scoped Member")
    )
    @team = Tenancy::Public.create_team(actor_membership: @owner.membership, name: "Scoped Team")
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

  test "unions direct and active-team permissions while preserving narrower scope" do
    direct = assign("viewer", "Membership", @member.id, "Project", @project_id)
    team = assign("analyst", "Team", @team.id, "Project", @project_id)
    property = assign("content_editor", "Membership", @member.id, "Property", @property_id)

    project_permissions = effective(@project_id, "Project")
    assert project_permissions.include?("projects.read")
    assert project_permissions.include?("usage.read")
    refute project_permissions.include?("members.read")
    assert_equal [ direct.id, team.id ].sort, project_permissions.assignment_ids

    property_permissions = effective(@property_id, "Property")
    assert property_permissions.include?("usage.read")
    assert property_permissions.include?("reports.generate")
    assert_equal [ direct.id, property.id, team.id ].sort, property_permissions.assignment_ids

    assert_empty effective(@other_project_id, "Project").permission_keys
  end

  test "inactive membership team scope and parent project grant nothing" do
    assign("viewer", "Membership", @member.id, "Project", @project_id)
    assign("analyst", "Team", @team.id, "Project", @project_id)

    Tenancy::Public.archive_team(actor_membership: @owner.membership, team_id: @team.id)
    refute effective(@project_id, "Project").include?("usage.read")

    Tenancy::Public.change_membership_status(
      actor_membership: @owner.membership, target_membership_id: @member.id, operation: "suspend"
    )
    assert_empty effective(@project_id, "Project").permission_keys
    Tenancy::Public.change_membership_status(
      actor_membership: @owner.membership, target_membership_id: @member.id, operation: "reactivate"
    )

    register_scope("Property", @property_id, project_id: @project_id, status: "archived")
    assert_empty effective(@property_id, "Property").permission_keys
    register_scope("Property", @property_id, project_id: @project_id)
    register_scope("Project", @project_id, status: "archived")
    assert_empty effective(@property_id, "Property").permission_keys
  end

  test "expired grants are ignored and effective resolution joins permissions without per-role queries" do
    expires_at = 5.minutes.from_now
    assign("viewer", "Membership", @member.id, "Project", @project_id).update!(expires_at: expires_at)

    sql = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      sql << payload.fetch(:sql) unless payload[:name] == "SCHEMA"
    end
    result = nil
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      result = Authorization::EffectivePermissionQuery.new(clock: -> { expires_at + 1.second }).call(
        organization_id: @owner.organization.id,
        membership_id: @member.id,
        scope_type: "Project",
        scope_id: @project_id
      )
    end

    assert_empty result.permission_keys
    permission_queries = sql.select do |statement|
      statement.start_with?('SELECT DISTINCT "permissions"."key", "role_assignments"."id"')
    end
    assert_equal 1, permission_queries.length, permission_queries.inspect
    refute sql.any? { |statement| statement.match?(/FROM \"roles\" WHERE/) }
  end

  test "rejects foreign principals scopes roles and property parents" do
    foreign = create_organization_for(slug: "scoped-role-foreign")
    foreign_project = SecureRandom.uuid
    Authorization::Public.register_scope(
      organization_id: foreign.organization.id,
      scope_type: "Project",
      scope_id: foreign_project
    )

    principal_error = assert_raises(Authorization::AssignmentDenied) do
      assign("viewer", "Membership", foreign.membership.id, "Project", @project_id)
    end
    assert_equal "scope_mismatch", principal_error.reason_code

    scope_error = assert_raises(Authorization::AssignmentDenied) do
      assign("viewer", "Membership", @member.id, "Project", foreign_project)
    end
    assert_equal "scope_mismatch", scope_error.reason_code

    foreign_role = create_custom_role(foreign.organization.id, "foreign_custom")
    role_error = assert_raises(Authorization::AssignmentDenied) do
      Authorization::Public.assign_role(
        actor_membership: @owner.membership,
        grantee_type: "Membership",
        grantee_id: @member.id,
        role_id: foreign_role.id,
        scope_type: "Project",
        scope_id: @project_id
      )
    end
    assert_equal "scope_mismatch", role_error.reason_code

    assert_raises(Authorization::AssignmentDenied) do
      Authorization::Public.register_scope(
        organization_id: @owner.organization.id,
        scope_type: "Property",
        scope_id: SecureRandom.uuid,
        project_id: foreign_project
      )
    end
  end

  test "requires grant authority prevents self escalation and rejects deny assignments" do
    viewer = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Viewer Actor")
    )
    admin = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Admin Actor")
    )
    target = Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: "Grant Target")
    )
    assign("viewer", "Membership", viewer.id, "Organization", @owner.organization.id)
    assign("organization_admin", "Membership", admin.id, "Organization", @owner.organization.id)

    unauthorized = assert_raises(Authorization::AssignmentDenied) do
      Authorization::Public.assign_role(
        actor_membership: viewer,
        grantee_type: "Membership",
        grantee_id: target.id,
        role_id: role("viewer").id,
        scope_type: "Project",
        scope_id: @project_id
      )
    end
    assert_equal "grant_authority_missing", unauthorized.reason_code

    self_escalation = assert_raises(Authorization::AssignmentDenied) do
      Authorization::Public.assign_role(
        actor_membership: admin,
        grantee_type: "Membership",
        grantee_id: admin.id,
        role_id: role("billing_admin").id,
        scope_type: "Organization",
        scope_id: @owner.organization.id
      )
    end
    assert_equal "self_escalation", self_escalation.reason_code

    exceeds = assert_raises(Authorization::AssignmentDenied) do
      Authorization::Public.assign_role(
        actor_membership: admin,
        grantee_type: "Membership",
        grantee_id: target.id,
        role_id: role("billing_admin").id,
        scope_type: "Organization",
        scope_id: @owner.organization.id
      )
    end
    assert_equal "grant_exceeds_authority", exceeds.reason_code

    deny = assert_raises(Authorization::AssignmentDenied) do
      Authorization::Public.assign_role(
        actor_membership: @owner.membership,
        grantee_type: "Membership",
        grantee_id: target.id,
        role_id: role("viewer").id,
        scope_type: "Project",
        scope_id: @project_id,
        effect: "deny"
      )
    end
    assert_equal "deny_not_supported", deny.reason_code
  end

  test "revocation is idempotent and assignment audit hashes every identifier" do
    assignment = assign("viewer", "Membership", @member.id, "Project", @project_id)
    first = Authorization::Public.revoke_role(
      actor_membership: @owner.membership, assignment_id: assignment.id
    )
    second = Authorization::Public.revoke_role(
      actor_membership: @owner.membership, assignment_id: assignment.id
    )

    assert_equal first.revoked_at, second.revoked_at
    assert_empty effective(@project_id, "Project").permission_keys
    event = parsed_events.find { |record| record["event_name"] == "authorization.role_assigned" }
    assert event
    %w[organization_id_hash actor_id_hash subject_id_hash role_id_hash scope_id_hash].each do |field|
      assert_match(/\A[0-9a-f]{24}\z/, event.fetch(field))
    end
    assert_equal "membership", event.fetch("principal_type")
    assert_equal "project", event.fetch("scope_type")
    [ @owner.organization.id, @owner.membership.id, @member.id, assignment.role_id, @project_id ].each do |raw_id|
      refute_includes event.to_json, raw_id
    end
  end

  private

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
      role_id: role(role_key).id,
      scope_type: scope_type,
      scope_id: scope_id
    )
  end

  def effective(scope_id, scope_type)
    Authorization::Public.effective_permissions(
      organization_id: @owner.organization.id,
      membership_id: @member.id,
      scope_type: scope_type,
      scope_id: scope_id
    )
  end

  def role(key)
    Authorization::Role.find_by!(system: true, key: key)
  end

  def create_custom_role(organization_id, key)
    Authorization::Role.create!(
      organization_id: organization_id,
      key: key,
      name: key.humanize,
      system: false,
      mutable: true,
      assignable_scopes: [ "project" ]
    )
  end

  def parsed_events
    @logger.entries.map(&:last).filter_map do |line|
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end
  end
end
