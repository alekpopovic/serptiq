# frozen_string_literal: true

require "test_helper"

class PropertiesPropertyDirectoryTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "property-directory")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "property-directory-project")
  end

  test "typed configurations are preloaded with a constant query count" do
    create_property_for(@owner, project: @project, kind: "website")
    one_count = query_count do
      Current.entitlement_cache = nil
      Properties::Public.property_page(actor_membership: @owner.membership, project_id: @project.id)
    end

    create_property_for(@owner, project: @project, kind: "android_app")
    create_property_for(@owner, project: @project, kind: "ios_app")
    page = nil
    many_count = query_count do
      Current.entitlement_cache = nil
      page = Properties::Public.property_page(
        actor_membership: @owner.membership, project_id: @project.id
      )
    end

    assert_equal one_count, many_count
    assert_equal 3, page.entries.length
    assert page.entries.all? { |entry| entry.identifier.present? }
  end

  test "project rollups count active properties in one grouped query" do
    active = create_property_for(@owner, project: @project, kind: "website")
    archived = create_property_for(@owner, project: @project, kind: "android_app")
    Properties::Public.transition_property(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: archived.id,
      operation: "archive"
    )

    rollups = nil
    count = query_count do
      rollups = Properties::Public.project_rollup_reader.call(project_ids: [ @project.id ])
    end
    assert_equal 1, count
    assert_equal 1, rollups.fetch(@project.id).property_count
    assert active.active?
  end

  private

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
