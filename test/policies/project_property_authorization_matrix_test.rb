# frozen_string_literal: true

require "test_helper"

class ProjectPropertyAuthorizationMatrixTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @alpha = build_organization("scope-alpha")
    @beta = build_organization("scope-beta")
    @alpha_projects = build_projects(@alpha, "alpha")
    @beta_projects = build_projects(@beta, "beta")
    @alpha_properties = build_properties(@alpha, @alpha_projects, "alpha")
    @beta_properties = build_properties(@beta, @beta_projects, "beta")
  end

  test "organization project and property grants obey the complete two-tenant hierarchy" do
    organization_viewer = add_member(@alpha, "Organization Viewer")
    assign(organization_viewer, "viewer", "Organization", @alpha.organization.id)
    assert_project_scope_access(
      actor: organization_viewer,
      organization: @alpha.organization,
      permission: "projects.read",
      allowed: @alpha_projects,
      denied: @beta_projects
    )
    assert_property_scope_access(
      actor: organization_viewer,
      organization: @alpha.organization,
      permission: "properties.read",
      allowed: property_pairs(@alpha_projects, @alpha_properties),
      denied: property_pairs(@beta_projects, @beta_properties)
    )

    project_viewer = add_member(@alpha, "Project Viewer")
    assign(project_viewer, "viewer", "Project", @alpha_projects.first.id)
    assert_project_scope_access(
      actor: project_viewer,
      organization: @alpha.organization,
      permission: "projects.read",
      allowed: @alpha_projects.first,
      denied: [ @alpha_projects.second, *@beta_projects ]
    )
    assert_property_scope_access(
      actor: project_viewer,
      organization: @alpha.organization,
      permission: "properties.read",
      allowed: pairs_for(@alpha_projects.first, @alpha_properties),
      denied: [ *pairs_for(@alpha_projects.second, @alpha_properties),
        *property_pairs(@beta_projects, @beta_properties) ]
    )

    property_viewer = add_member(@alpha, "Property Viewer")
    exact_property = @alpha_properties.fetch(@alpha_projects.first.id).first
    custom_role = create_property_boundary_role
    assign_role(property_viewer, custom_role, "Property", exact_property.id)
    assert_property_scope_access(
      actor: property_viewer,
      organization: @alpha.organization,
      permission: "properties.read",
      allowed: [ [ @alpha_projects.first, exact_property ] ],
      denied: [
        [ @alpha_projects.first, @alpha_properties.fetch(@alpha_projects.first.id).second ],
        *pairs_for(@alpha_projects.second, @alpha_properties),
        *property_pairs(@beta_projects, @beta_properties)
      ]
    )
    assert_project_scope_access(
      actor: property_viewer,
      organization: @alpha.organization,
      permission: "projects.read",
      allowed: [],
      denied: [ *@alpha_projects, *@beta_projects ]
    )
    %w[members.read billing.read organization.update].each do |permission|
      assert scoped_decision(
        actor: property_viewer,
        organization: @alpha.organization,
        permission: permission
      ).deny?, "property grant unexpectedly allowed #{permission}"
    end
  end

  test "team lifecycle assignment expiry and suspended membership match the central resolver" do
    member = add_member(@alpha, "Team Viewer")
    team = Tenancy::Public.create_team(actor_membership: @alpha.membership, name: "Scoped Client Team")
    Tenancy::Public.add_team_member(
      actor_membership: @alpha.membership, team_id: team.id, membership_id: member.id
    )
    assignment = assign(team, "viewer", "Project", @alpha_projects.second.id,
      grantee_type: "Team", expires_at: 30.minutes.from_now)

    assert_project_scope_access(
      actor: member,
      organization: @alpha.organization,
      permission: "projects.read",
      allowed: @alpha_projects.second,
      denied: @alpha_projects.first
    )
    travel 31.minutes
    assert_project_scope_access(
      actor: member,
      organization: @alpha.organization,
      permission: "projects.read",
      allowed: [],
      denied: @alpha_projects
    )
    travel_back

    Tenancy::Public.archive_team(actor_membership: @alpha.membership, team_id: team.id)
    assert scoped_decision(
      actor: member,
      organization: @alpha.organization,
      permission: "projects.read",
      project: @alpha_projects.second
    ).deny?
    refute assignment.reload.revoked_at

    direct = assign(member, "viewer", "Organization", @alpha.organization.id)
    assert direct.active_at?(Time.current)
    Tenancy::Public.change_membership_status(
      actor_membership: @alpha.membership,
      target_membership_id: member.id,
      operation: "suspend"
    )
    assert scoped_decision(
      actor: member,
      organization: @alpha.organization,
      permission: "projects.read",
      project: @alpha_projects.first
    ).deny?
  end

  test "archived exact scopes cannot restore while ancestor grants retain review access" do
    scoped_project_member = add_member(@alpha, "Archived Project Viewer")
    organization_member = add_member(@alpha, "Archived Organization Viewer")
    assign(scoped_project_member, "seo_lead", "Project", @alpha_projects.first.id)
    assign(organization_member, "seo_lead", "Organization", @alpha.organization.id)
    Projects::Public.transition_project(
      actor_membership: @alpha.membership,
      project_id: @alpha_projects.first.id,
      operation: "archive"
    )

    refute scoped_decision(
      actor: scoped_project_member,
      organization: @alpha.organization,
      permission: "projects.archive",
      project: @alpha_projects.first
    ).allow?
    assert scoped_decision(
      actor: organization_member,
      organization: @alpha.organization,
      permission: "projects.archive",
      project: @alpha_projects.first
    ).allow?

    property = @alpha_properties.fetch(@alpha_projects.second.id).first
    scoped_property_member = add_member(@alpha, "Archived Property Developer")
    parent_member = add_member(@alpha, "Parent Project Developer")
    assign(scoped_property_member, "developer", "Property", property.id)
    assign(parent_member, "developer", "Project", @alpha_projects.second.id)
    Properties::Public.transition_property(
      actor_membership: @alpha.membership,
      project_id: @alpha_projects.second.id,
      property_id: property.id,
      operation: "archive"
    )

    refute scoped_decision(
      actor: scoped_property_member,
      organization: @alpha.organization,
      permission: "properties.manage",
      project: @alpha_projects.second,
      property: property
    ).allow?
    assert scoped_decision(
      actor: parent_member,
      organization: @alpha.organization,
      permission: "properties.manage",
      project: @alpha_projects.second,
      property: property
    ).allow?
  end

  test "successful mutations audit the authorized actor and unauthorized siblings audit nothing" do
    project_actor = add_member(@alpha, "Project Editor")
    assign(project_actor, "developer", "Project", @alpha_projects.first.id)
    Projects::Public.update_project(
      actor_membership: project_actor,
      project_id: @alpha_projects.first.id,
      name: "Authorized Alpha Project",
      description: "",
      default_locale: "en",
      time_zone: "UTC"
    )
    project_audit = Auditing::AuditEvent.find_by!(
      action: "project.updated", target_id: @alpha_projects.first.id
    )
    assert_equal project_actor.id, project_audit.actor_membership_id
    assert_equal @alpha.organization.id, project_audit.organization_id

    property_actor = add_member(@alpha, "Property Editor")
    property = @alpha_properties.fetch(@alpha_projects.first.id).first
    sibling = @alpha_properties.fetch(@alpha_projects.first.id).second
    assign(property_actor, "developer", "Property", property.id)
    Properties::Public.update_property(
      actor_membership: property_actor,
      project_id: @alpha_projects.first.id,
      property_id: property.id,
      display_name: "Authorized Alpha Property",
      configuration: property.configuration_record.value.to_h
    )
    property_audit = Auditing::AuditEvent.find_by!(
      action: "property.updated", target_id: property.id
    )
    assert_equal property_actor.id, property_audit.actor_membership_id
    assert_equal @alpha.organization.id, property_audit.organization_id

    assert_no_difference("Auditing::AuditEvent.count") do
      assert_raises(Authorization::AccessDenied) do
        Properties::Public.update_property(
          actor_membership: property_actor,
          project_id: @alpha_projects.first.id,
          property_id: sibling.id,
          display_name: "Unauthorized Rename",
          configuration: sibling.configuration_record.value.to_h
        )
      end
    end
    refute_equal "Unauthorized Rename", sibling.reload.display_name
  end

  private

  def build_organization(slug)
    create_organization_for(slug: slug).tap do |result|
      enable_project_limit(result, limit: 10)
      enable_property_limits(result, website: 10, mobile: 10)
    end
  end

  def build_projects(result, prefix)
    2.times.map do |index|
      create_project_for(
        result,
        name: "#{prefix.capitalize} Project #{index + 1}",
        slug: "#{prefix}-project-#{index + 1}"
      )
    end
  end

  def build_properties(result, projects, prefix)
    projects.to_h do |project|
      records = 2.times.map do |index|
        create_property_for(
          result,
          project: project,
          display_name: "#{prefix.capitalize} #{project.slug} Property #{index + 1}"
        )
      end
      [ project.id, records ]
    end
  end

  def property_pairs(projects, properties)
    projects.flat_map { |project| pairs_for(project, properties) }
  end

  def pairs_for(project, properties)
    properties.fetch(project.id).map { |property| [ project, property ] }
  end

  def add_member(result, name)
    Tenancy::Public.create_membership(
      actor_membership: result.membership,
      user: create_identity_user(display_name: name)
    )
  end

  def assign(principal, role_key, scope_type, scope_id, grantee_type: "Membership", expires_at: nil)
    assign_role(
      principal,
      Authorization::Role.find_by!(system: true, key: role_key),
      scope_type,
      scope_id,
      grantee_type: grantee_type,
      expires_at: expires_at
    )
  end

  def assign_role(principal, role, scope_type, scope_id, grantee_type: "Membership", expires_at: nil)
    Authorization::Public.assign_role(
      actor_membership: @alpha.membership,
      grantee_type: grantee_type,
      grantee_id: principal.id,
      role_id: role.id,
      scope_type: scope_type,
      scope_id: scope_id,
      expires_at: expires_at
    )
  end

  def create_property_boundary_role
    role = Authorization::Role.create!(
      organization_id: @alpha.organization.id,
      key: "property_boundary_probe",
      name: "Property Boundary Probe",
      system: false,
      mutable: true,
      assignable_scopes: [ "project" ]
    )
    %w[projects.read properties.read members.read billing.read organization.update].each do |key|
      Authorization::RolePermission.create!(
        role: role, permission: Authorization::Permission.find_by!(key: key)
      )
    end
    role
  end
end
