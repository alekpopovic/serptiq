# frozen_string_literal: true

require "test_helper"

class ProjectsProjectDirectoryTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "project-directory")
    enable_project_limit(@owner, limit: 20)
  end

  test "bulk placeholder summaries keep query count constant as a page grows" do
    create_project_for(@owner, name: "One Project", slug: "one-project")
    one_count = query_count do
      Current.entitlement_cache = nil
      Projects::Public.project_page(actor_membership: @owner.membership)
    end

    5.times { |index| create_project_for(@owner, name: "More #{index}", slug: "more-#{index}") }
    many_page = nil
    many_count = query_count do
      Current.entitlement_cache = nil
      many_page = Projects::Public.project_page(actor_membership: @owner.membership)
    end

    assert_equal one_count, many_count
    assert_equal 6, many_page.entries.length
    assert many_page.entries.all? { |entry| entry.property_count.zero? }
    assert many_page.entries.all? { |entry| entry.health_state == "not_observed" }
    assert many_page.entries.all? { |entry| entry.latest_scan_state == "not_available" }
  end

  test "organization grants include archived history while archived project grants do not" do
    project = create_project_for(@owner, slug: "history-project")
    scoped_member = add_member("Project Viewer")
    organization_member = add_member("Organization Viewer")
    viewer = Authorization::Role.find_by!(system: true, key: "viewer")
    assign(viewer, scoped_member, "Project", project.id)
    assign(viewer, organization_member, "Organization", @owner.organization.id)

    Projects::Public.transition_project(
      actor_membership: @owner.membership, project_id: project.id, operation: "archive"
    )

    assert_empty Projects::Public.project_page(actor_membership: scoped_member).entries
    entries = Projects::Public.project_page(actor_membership: organization_member).entries
    assert_equal [ project.id ], entries.map(&:id)
    assert entries.first.archived?
  end

  private

  def add_member(name)
    Tenancy::Public.create_membership(
      actor_membership: @owner.membership,
      user: create_identity_user(display_name: name)
    )
  end

  def assign(role, member, scope_type, scope_id)
    Authorization::Public.assign_role(
      actor_membership: @owner.membership,
      grantee_type: "Membership",
      grantee_id: member.id,
      role_id: role.id,
      scope_type: scope_type,
      scope_id: scope_id
    )
  end

  def query_count
    count = 0
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      sql = payload[:sql].to_s
      count += 1 if payload[:name] != "SCHEMA" && sql.match?(/\ASELECT/i)
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    count
  end
end
