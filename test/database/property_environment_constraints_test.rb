# frozen_string_literal: true

require "test_helper"

class PropertyEnvironmentConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @first = create_organization_for(slug: "environment-constraints-one")
    @second = create_organization_for(slug: "environment-constraints-two")
    [ @first, @second ].each do |owner|
      enable_project_limit(owner)
      enable_property_limits(owner)
    end
    @first_project = create_project_for(@first, slug: "environment-constraints-first")
    @second_project = create_project_for(@second, slug: "environment-constraints-second")
    @property = create_property_for(@first, project: @first_project)
  end

  test "composite foreign key rejects a cross-tenant property environment" do
    assert_database_rejects do
      insert_environment(
        organization_id: @second.organization.id,
        project_id: @second_project.id,
        property_id: @property.id,
        origin: "https://cross-tenant.example.com"
      )
    end
  end

  test "database rejects malformed canonical components and duplicate project origin" do
    staging = create_environment("staging", "https://staging.example.com")
    other_property = create_property_for(
      @first,
      project: @first_project,
      display_name: "Other web property",
      configuration: { origin: "https://other.example.com" }
    )

    assert_database_rejects do
      staging.update_columns(host: "different.example.com")
    end
    assert_database_rejects do
      insert_environment(
        organization_id: @first.organization.id,
        project_id: @first_project.id,
        property_id: other_property.id,
        origin: staging.origin,
        key: "duplicate"
      )
    end
  end

  test "database enforces stable key kind and exactly one primary for an active web property" do
    primary = @property.environments.sole

    assert_database_rejects { primary.update_columns(key: "renamed") }
    assert_database_rejects { primary.update_columns(kind: "custom") }
    assert_database_rejects do
      ActiveRecord::Base.connection.execute(
        "SET CONSTRAINTS property_environments_require_primary IMMEDIATE"
      )
      primary.update_columns(primary: false)
    end
    assert primary.reload.primary?
  end

  test "database rejects primary non-production and invalid lifecycle" do
    staging = create_environment("staging", "https://staging-two.example.com")

    assert_database_rejects { staging.update_columns(primary: true) }
    assert_database_rejects { staging.update_columns(status: "archived", archived_at: nil) }
  end

  private

  def create_environment(key, origin)
    Properties::Public.create_environment(
      actor_membership: @first.membership,
      project_id: @first_project.id,
      property_id: @property.id,
      key: key,
      kind: "staging",
      display_name: key.humanize,
      origin: origin
    )
  end

  def insert_environment(organization_id:, project_id:, property_id:, origin:, key: "foreign")
    property = Properties::Property.find(property_id)
    value = Properties::CanonicalOrigin.new(origin: origin)
    now = Time.current
    Properties::Environment.insert!({
      id: SecureRandom.uuid,
      organization_id: organization_id,
      project_id: project_id,
      property_id: property_id,
      property_kind: property.kind,
      configuration_version: property.configuration_version,
      key: key,
      kind: "custom",
      display_name: key.humanize,
      primary: false,
      status: "active",
      scheme: value.scheme,
      host: value.host,
      port: value.port,
      origin: value.origin,
      created_at: now,
      updated_at: now
    })
  end

  def assert_database_rejects(&block)
    assert_raises(ActiveRecord::StatementInvalid) do
      Properties::Environment.transaction(requires_new: true, &block)
    end
  end
end
