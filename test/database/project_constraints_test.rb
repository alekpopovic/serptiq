# frozen_string_literal: true

require "test_helper"

class ProjectConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @first = create_organization_for(slug: "project-constraints-one")
    @second = create_organization_for(slug: "project-constraints-two")
    enable_project_limit(@first)
    enable_project_limit(@second)
  end

  test "database enforces tenant slug uniqueness while allowing another tenant to use the same slug" do
    create_project_for(@first, name: "First", slug: "shared-key")
    assert create_project_for(@second, name: "Second", slug: "shared-key")

    assert_raises(ActiveRecord::RecordInvalid) do
      create_project_for(@first, name: "Duplicate", slug: "SHARED KEY")
    end

    scope_id = SecureRandom.uuid
    Authorization::Public.register_scope(
      organization_id: @first.organization.id, scope_type: "Project", scope_id: scope_id
    )
    assert_database_rejects do
      insert_project(id: scope_id, organization_id: @first.organization.id, slug: "shared-key")
    end
  end

  test "database rejects lifecycle shapes and a foreign authorization scope" do
    project = create_project_for(@first, slug: "guarded-project")
    foreign_scope_id = SecureRandom.uuid
    Authorization::Public.register_scope(
      organization_id: @second.organization.id,
      scope_type: "Project",
      scope_id: foreign_scope_id
    )
    now = Time.current

    assert_database_rejects do
      Projects::Project.insert!({
        id: foreign_scope_id,
        organization_id: @first.organization.id,
        slug: "foreign-scope",
        name: "Foreign Scope",
        description: "",
        status: "active",
        default_locale: "en",
        time_zone: "UTC",
        external_release_key: "prj_#{'c' * 32}",
        authorization_scope_type: "Project",
        created_at: now,
        updated_at: now
      })
    end

    assert_database_rejects do
      project.update_columns(status: "archived", archived_at: nil)
    end
  end

  test "database rejects malformed and duplicate external release keys" do
    project = create_project_for(@first, slug: "release-key-one")
    scope_id = SecureRandom.uuid
    Authorization::Public.register_scope(
      organization_id: @first.organization.id, scope_type: "Project", scope_id: scope_id
    )
    now = Time.current

    assert_database_rejects do
      Projects::Project.insert!({
        id: scope_id,
        organization_id: @first.organization.id,
        slug: "release-key-two",
        name: "Release Key Two",
        description: "",
        status: "active",
        default_locale: "en",
        time_zone: "UTC",
        external_release_key: project.external_release_key,
        authorization_scope_type: "Project",
        created_at: now,
        updated_at: now
      })
    end
  end

  private

  def assert_database_rejects(&block)
    assert_raises(ActiveRecord::StatementInvalid) do
      Projects::Project.transaction(requires_new: true, &block)
    end
  end

  def insert_project(id:, organization_id:, slug:)
    now = Time.current
    Projects::Project.insert!({
      id: id,
      organization_id: organization_id,
      slug: slug,
      name: "Constraint project",
      description: "",
      status: "active",
      default_locale: "en",
      time_zone: "UTC",
      external_release_key: "prj_#{SecureRandom.hex(16)}",
      authorization_scope_type: "Project",
      created_at: now,
      updated_at: now
    })
  end
end
