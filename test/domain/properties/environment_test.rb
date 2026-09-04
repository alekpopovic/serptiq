# frozen_string_literal: true

require "test_helper"

class PropertiesEnvironmentTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "property-environment-domain")
    enable_project_limit(@owner)
    enable_property_limits(@owner)
    @project = create_project_for(@owner, slug: "environment-project")
    @property = create_property_for(
      @owner,
      project: @project,
      kind: "website",
      configuration: { origin: "https://www.example.com" }
    )
  end

  test "website property starts with one primary production environment" do
    environment = @property.environments.sole

    assert_equal [ "production", "production", true, "active" ],
      environment.values_at(:key, :kind, :primary, :status)
    assert_equal @property.website_property_config.origin, environment.origin
    assert_equal 2, Auditing::AuditEvent.where(
      organization_id: @owner.organization.id,
      action: [ "property.created", "property_environment.created" ]
    ).count
  end

  test "creates a normalized IDNA staging environment with sanitized history" do
    environment = Properties::Public.create_environment(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      key: "staging-eu",
      kind: "staging",
      display_name: "European staging",
      origin: "HTTPS://BÜCHER.Example.:443/"
    )

    assert_equal "https://xn--bcher-kva.example", environment.origin
    assert_equal "https://bücher.example", environment.origin_value.display_origin
    audit = Auditing::AuditEvent.find_by!(
      action: "property_environment.created", target_id: environment.id
    )
    refute_includes audit.metadata.to_json, "bücher"
    refute_includes audit.metadata.to_json, "xn--"
    event = Shared::Events::OutboxEvent.find_by!(
      event_type: "property_environment.created", aggregate_id: environment.id
    )
    refute_includes event.payload.to_json, environment.origin
  end

  test "origin change invalidates property verification and updates primary configuration" do
    @property.update_columns(verification_status: "verified", verified_at: 1.hour.ago)
    environment = @property.environments.sole

    result = Properties::Public.update_environment(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: environment.id,
      display_name: "Primary production",
      origin: "https://docs.example.com",
      primary: true
    )

    assert result.changed?
    assert_equal "https://docs.example.com", @property.website_property_config.reload.origin
    assert_equal [ "unverified", nil ], @property.reload.values_at(:verification_status, :verified_at)
    audit = Auditing::AuditEvent.find_by!(
      action: "property_environment.updated", target_id: environment.id
    )
    assert_equal %w[display_name origin], audit.metadata.fetch("changed_fields")
  end

  test "selecting an existing production environment as primary invalidates verification" do
    candidate = Properties::Public.create_environment(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      key: "production-next",
      kind: "production",
      display_name: "Next production",
      origin: "https://next.example.com"
    )
    @property.update_columns(verification_status: "verified", verified_at: 1.hour.ago)

    Properties::Public.update_environment(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: candidate.id,
      display_name: candidate.display_name,
      origin: candidate.origin,
      primary: true
    )

    assert candidate.reload.primary?
    assert_equal "https://next.example.com", @property.website_property_config.reload.origin
    assert_equal [ "unverified", nil ], @property.reload.values_at(:verification_status, :verified_at)
  end

  test "stable key and kind cannot change and the primary environment cannot be archived" do
    primary = @property.environments.sole
    primary.key = "renamed"
    primary.kind = "custom"
    refute primary.valid?
    assert_includes primary.errors[:key], "cannot be changed"
    assert_includes primary.errors[:kind], "cannot be changed"

    error = assert_raises(Properties::PropertyTransitionInvalid) do
      Properties::Public.transition_environment(
        actor_membership: @owner.membership,
        project_id: @project.id,
        property_id: @property.id,
        environment_id: primary.id,
        operation: "archive"
      )
    end
    assert_equal "primary_environment_required", error.reason_code
  end

  test "archives and reactivates a non-primary environment without making it primary" do
    environment = create_staging

    archived = Properties::Public.transition_environment(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: environment.id,
      operation: "archive"
    )
    assert archived.archived?
    refute archived.primary?

    restored = Properties::Public.transition_environment(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      environment_id: environment.id,
      operation: "reactivate"
    )
    assert restored.active?
    refute restored.primary?
  end

  test "rejects cross-tenant property substitution" do
    foreign = create_organization_for(slug: "foreign-environment-domain")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    foreign_project = create_project_for(foreign, slug: "foreign-environment-project")
    foreign_property = create_property_for(foreign, project: foreign_project)

    assert_raises(Properties::PropertyAccessDenied) do
      Properties::Public.create_environment(
        actor_membership: @owner.membership,
        project_id: foreign_project.id,
        property_id: foreign_property.id,
        key: "staging",
        kind: "staging",
        display_name: "Staging",
        origin: "https://staging.foreign.example.com"
      )
    end
  end

  private

  def create_staging
    Properties::Public.create_environment(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: @property.id,
      key: "staging",
      kind: "staging",
      display_name: "Staging",
      origin: "https://staging.example.com"
    )
  end
end
