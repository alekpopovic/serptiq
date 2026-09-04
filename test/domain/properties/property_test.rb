# frozen_string_literal: true

require "test_helper"

class PropertiesPropertyTest < ActiveSupport::TestCase
  setup do
    Authorization::Public.sync_catalog
    @owner = create_organization_for(slug: "typed-property-domain")
    enable_project_limit(@owner)
    enable_property_limits(@owner, website: 3, mobile: 3)
    @project = create_project_for(@owner, slug: "typed-property-project")
  end

  test "creates every versioned property type with one normalized typed configuration" do
    role_count = Authorization::RoleAssignment.count
    website = create_property_for(
      @owner, project: @project, kind: "website", display_name: "Marketing site",
      configuration: { origin: " HTTPS://WWW.EXAMPLE.COM:443/ " }
    )
    web_app = create_property_for(
      @owner, project: @project, kind: "web_application", display_name: "Customer app",
      configuration: { origin: "https://app.example.com:8443" }
    )
    android = create_property_for(
      @owner, project: @project, kind: "android_app", display_name: "Android app",
      configuration: { package_name: " COM.Example.Mobile " }
    )
    ios = create_property_for(
      @owner, project: @project, kind: "ios_app", display_name: "iOS app",
      configuration: { bundle_id: " COM.Example.Mobile ", team_id: "a1b2c3d4e5" }
    )

    assert_equal "https://www.example.com", website.website_property_config.origin
    assert_equal [ "https", "www.example.com", 443 ], website.website_property_config
      .attributes.values_at("scheme", "host", "port")
    assert_equal "https://app.example.com:8443", web_app.website_property_config.origin
    assert_equal "com.example.mobile", android.android_property_config.package_name
    assert_equal [ "com.example.mobile", "A1B2C3D4E5" ],
      ios.ios_property_config.attributes.values_at("bundle_id", "team_id")
    assert_equal 4, Authorization::ScopeReference.where(scope_type: "Property").count
    assert_equal role_count, Authorization::RoleAssignment.count
    assert [ website, web_app, android, ios ].all? { |property| property.configuration_version == 1 }
  end

  test "rejects malformed and unsupported configurations without partial scope records" do
    assert_no_difference([ "Properties::Property.count", "Authorization::ScopeReference.count" ]) do
      assert_raises(ArgumentError) do
        create_property_for(
          @owner, project: @project, kind: "website",
          configuration: { origin: "https://user:secret@example.com/path" }
        )
      end
    end

    assert_no_difference([ "Properties::Property.count", "Authorization::ScopeReference.count" ]) do
      assert_raises(ArgumentError) do
        create_property_for(@owner, project: @project, kind: "future_device", configuration: {})
      end
    end
  end

  test "domain creation rejects a project from another tenant before scope registration" do
    foreign = create_organization_for(slug: "foreign-property-domain")
    enable_project_limit(foreign)
    enable_property_limits(foreign)
    foreign_project = create_project_for(foreign, slug: "foreign-property-domain-project")

    assert_no_difference([ "Properties::Property.count", "Authorization::ScopeReference.count" ]) do
      assert_raises(Properties::PropertyAccessDenied) do
        Properties::Public.create_property(
          actor_membership: @owner.membership,
          project_id: foreign_project.id,
          kind: "website",
          display_name: "Foreign project property",
          configuration: { origin: "https://foreign.example.com" }
        )
      end
    end
  end

  test "material association changes reset verification and emit sanitized history" do
    property = create_property_for(
      @owner, project: @project, kind: "android_app",
      configuration: { package_name: "com.example.old" }
    )
    verified_at = 1.hour.ago
    property.update_columns(verification_status: "verified", verified_at: verified_at)

    result = Properties::Public.update_property(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: property.id,
      display_name: property.display_name,
      configuration: { package_name: "com.example.new" }
    )

    assert result.changed?
    assert_equal [ "unverified", nil ], property.reload.values_at(:verification_status, :verified_at)
    assert_equal "com.example.new", property.android_property_config.reload.package_name
    audit = Auditing::AuditEvent.find_by!(action: "property.updated", target_id: property.id)
    assert_equal %w[verification_status verified_at configuration],
      audit.metadata.fetch("changed_fields")
    refute_includes audit.metadata.to_json, "com.example"
    assert Shared::Events::OutboxEvent.exists?(event_type: "property.updated", aggregate_id: property.id)
  end

  test "archive and reactivate preserve configuration and synchronize scope availability" do
    property = create_property_for(@owner, project: @project, kind: "ios_app")
    identifier = property.ios_property_config.value.identifier

    archived = Properties::Public.transition_property(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: property.id,
      operation: "archive"
    )
    assert archived.changed?
    assert archived.property.archived?
    refute archived.property.scan_available?
    assert Authorization::ScopeReference.find(property.id).archived?

    restored = Properties::Public.transition_property(
      actor_membership: @owner.membership,
      project_id: @project.id,
      property_id: property.id,
      operation: "reactivate"
    )
    assert restored.changed?
    assert restored.property.active?
    assert_equal identifier, restored.property.ios_property_config.value.identifier
    assert Authorization::ScopeReference.find(property.id).active?
  end

  test "website and mobile limits are independent and archived properties release capacity" do
    owner = create_organization_for(slug: "property-limit-domain")
    enable_project_limit(owner)
    enable_property_limits(owner, website: 1, mobile: 1)
    project = create_project_for(owner, slug: "property-limit-project")
    website = create_property_for(owner, project: project, kind: "website")
    assert create_property_for(owner, project: project, kind: "android_app")

    error = assert_raises(Properties::PropertyLimitReached) do
      create_property_for(owner, project: project, kind: "web_application")
    end
    assert_equal "website_properties.max", error.entitlement_key

    Properties::Public.transition_property(
      actor_membership: owner.membership,
      project_id: project.id,
      property_id: website.id,
      operation: "archive"
    )
    assert create_property_for(owner, project: project, kind: "web_application")
  end

  test "property type and parent are immutable and no tenant default scope is used" do
    property = create_property_for(@owner, project: @project)
    property.kind = "android_app"
    refute property.valid?
    assert_includes property.errors[:kind], "cannot be changed"
    assert_empty Properties::Property.default_scopes
  end
end
