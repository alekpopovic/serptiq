# frozen_string_literal: true

require "test_helper"

class ProjectsProjectTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(name: "Project Domain", slug: "project-domain")
    enable_project_limit(@owner, limit: 2)
  end

  test "creates a tenant project with stable identifiers scope audit and outbox evidence" do
    now = Time.current.change(usec: 0)
    role_assignment_count = Authorization::RoleAssignment.count
    project = Projects::CreateProject.new(
      clock: -> { now },
      id_generator: -> { "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" },
      release_key_generator: -> { "prj_#{'b' * 32}" }
    ).call(
      actor_membership: @owner.membership,
      name: "  International Store  ",
      slug: " International Štore ",
      description: "  Product discovery surfaces  ",
      default_locale: "en",
      time_zone: "UTC"
    )

    assert_equal "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", project.id
    assert_equal @owner.organization.id, project.organization_id
    assert_equal "International Store", project.name
    assert_equal "international-store", project.slug
    assert_equal "Product discovery surfaces", project.description
    assert_equal "prj_#{'b' * 32}", project.external_release_key
    assert project.active?
    assert project.scan_available?

    scope = Authorization::ScopeReference.find(project.id)
    assert_equal @owner.organization.id, scope.organization_id
    assert_equal "Project", scope.scope_type
    assert scope.active?
    assert_equal role_assignment_count, Authorization::RoleAssignment.count
    assert Auditing::AuditEvent.exists?(action: "project.created", target_id: project.id)
    assert Shared::Events::OutboxEvent.exists?(event_type: "project.created", aggregate_id: project.id)
  end

  test "stable tenant route and release identities cannot be changed" do
    project = create_project_for(@owner, slug: "stable-project")

    project.slug = "replacement-project"
    refute project.valid?
    assert_includes project.errors[:slug], "cannot be changed"

    assert_raises(ActiveRecord::StatementInvalid) do
      Projects::Project.transaction(requires_new: true) do
        project.reload.update_columns(slug: "replacement-project")
      end
    end
  end

  test "central lifecycle preserves history and synchronizes authorization availability" do
    now = Time.current.change(usec: 0)
    project = create_project_for(@owner, slug: "lifecycle-project", at: now)

    archived = Projects::Public.transition_project(
      actor_membership: @owner.membership,
      project_id: project.id,
      operation: "archive",
      clock: -> { now + 1.minute }
    )
    assert archived.changed?
    assert archived.project.archived?
    refute archived.project.scan_available?
    assert Authorization::ScopeReference.find(project.id).archived?

    restored = Projects::Public.transition_project(
      actor_membership: @owner.membership,
      project_id: project.id,
      operation: "reactivate",
      clock: -> { now + 2.minutes }
    )
    assert restored.changed?
    assert restored.project.active?
    assert Authorization::ScopeReference.find(project.id).active?

    workflow = Administration::Public.request_resource_deletion(
      actor_membership: @owner.membership,
      target_type: "Project",
      project_id: project.id,
      current_session: issue_identity_session(user: @owner.membership.user).session,
      user_id: @owner.membership.user_id,
      clock: -> { now + 3.minutes }
    )
    assert workflow.holding?
    assert project.reload.pending_deletion?
    assert_equal now + 3.minutes, project.deletion_requested_at
    assert Authorization::ScopeReference.find(project.id).archived?

    assert_raises(Projects::ProjectTransitionInvalid) do
      Projects::Public.transition_project(
        actor_membership: @owner.membership,
        project_id: project.id,
        operation: "reactivate"
      )
    end
  end

  test "active project limit is serialized and archived projects release capacity" do
    first = create_project_for(@owner, slug: "limit-one")
    create_project_for(@owner, slug: "limit-two")

    error = assert_raises(Projects::ProjectLimitReached) do
      create_project_for(@owner, slug: "limit-three")
    end
    assert_equal 2, error.limit
    assert_equal 2, error.active_count

    Projects::Public.transition_project(
      actor_membership: @owner.membership, project_id: first.id, operation: "archive"
    )
    assert create_project_for(@owner, slug: "limit-three").active?
  end

  test "updates reject archived projects and foreign tenant identifiers" do
    project = create_project_for(@owner, slug: "editable-project")
    foreign = create_organization_for(slug: "foreign-project-domain")
    enable_project_limit(foreign)

    updated = Projects::Public.update_project(
      actor_membership: @owner.membership,
      project_id: project.id,
      name: "Updated project",
      description: "Updated context",
      default_locale: "en",
      time_zone: "Belgrade"
    )
    assert_equal "Updated project", updated.name

    assert_raises(Projects::ProjectAccessDenied) do
      Projects::Public.update_project(
        actor_membership: foreign.membership,
        project_id: project.id,
        name: "Cross tenant",
        description: "",
        default_locale: "en",
        time_zone: "UTC"
      )
    end

    Projects::Public.transition_project(
      actor_membership: @owner.membership, project_id: project.id, operation: "archive"
    )
    assert_raises(Authorization::AccessDenied) do
      Projects::Public.update_project(
        actor_membership: @owner.membership,
        project_id: project.id,
        name: "Archived rewrite",
        description: "",
        default_locale: "en",
        time_zone: "UTC"
      )
    end
  end

  test "project records never use a tenant default scope" do
    assert_empty Projects::Project.default_scopes
  end
end
