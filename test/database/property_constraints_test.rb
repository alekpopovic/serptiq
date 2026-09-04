# frozen_string_literal: true

require "test_helper"

class PropertyConstraintsTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @first = create_organization_for(slug: "property-constraints-one")
    @second = create_organization_for(slug: "property-constraints-two")
    [ @first, @second ].each do |owner|
      enable_project_limit(owner)
      enable_property_limits(owner)
    end
    @first_project = create_project_for(@first, slug: "constraints-first")
    @second_project = create_project_for(@second, slug: "constraints-second")
  end

  test "database rejects a foreign project and duplicate normalized display name" do
    create_property_for(
      @first, project: @first_project, display_name: "Shared Property",
      configuration: { origin: "https://one.example.com" }
    )

    foreign_property_id = register_property_scope(@first, @first_project)
    assert_database_rejects do
      insert_property(
        id: foreign_property_id,
        owner: @first,
        project: @second_project,
        display_name: "Foreign Parent"
      )
    end

    duplicate_id = register_property_scope(@first, @first_project)
    assert_database_rejects do
      insert_property(
        id: duplicate_id,
        owner: @first,
        project: @first_project,
        display_name: "shared property"
      )
    end
  end

  test "typed configuration foreign key rejects a configuration for the wrong kind" do
    property = create_property_for(@first, project: @first_project, kind: "android_app")
    now = Time.current

    assert_database_rejects do
      Properties::WebsitePropertyConfig.insert!({
        property_id: property.id,
        organization_id: property.organization_id,
        project_id: property.project_id,
        property_kind: "website",
        configuration_version: 1,
        scheme: "https",
        host: "wrong.example.com",
        port: 443,
        origin: "https://wrong.example.com",
        created_at: now,
        updated_at: now
      })
    end
  end

  test "database enforces normalized identifiers and immutable type" do
    first = create_property_for(
      @first, project: @first_project, kind: "website",
      configuration: { origin: "https://unique.example.com" }
    )
    second = create_property_for(
      @first, project: @first_project, kind: "website",
      configuration: { origin: "https://other.example.com" }
    )

    assert_database_rejects do
      second.website_property_config.update_columns(
        scheme: first.website_property_config.scheme,
        host: first.website_property_config.host,
        port: first.website_property_config.port,
        origin: first.website_property_config.origin
      )
    end
    assert_database_rejects { first.update_columns(kind: "android_app") }
  end

  test "database rejects malformed package bundle team and lifecycle values" do
    android = create_property_for(@first, project: @first_project, kind: "android_app")
    ios = create_property_for(@first, project: @first_project, kind: "ios_app")

    assert_database_rejects do
      android.android_property_config.update_columns(package_name: "not a package")
    end
    assert_database_rejects { ios.ios_property_config.update_columns(team_id: "short") }
    assert_database_rejects { android.update_columns(status: "archived", archived_at: nil) }
  end

  private

  def register_property_scope(owner, project)
    id = SecureRandom.uuid
    Authorization::Public.register_scope(
      organization_id: owner.organization.id,
      scope_type: "Property",
      scope_id: id,
      project_id: project.id
    )
    id
  end

  def insert_property(id:, owner:, project:, display_name:)
    now = Time.current
    Properties::Property.insert!({
      id: id,
      organization_id: owner.organization.id,
      project_id: project.id,
      display_name: display_name,
      kind: "website",
      status: "active",
      verification_status: "unverified",
      configuration_version: 1,
      authorization_scope_type: "Property",
      authorization_project_scope_type: "Project",
      created_at: now,
      updated_at: now
    })
  end

  def assert_database_rejects(&block)
    assert_raises(ActiveRecord::StatementInvalid) do
      Properties::Property.transaction(requires_new: true, &block)
    end
  end
end
