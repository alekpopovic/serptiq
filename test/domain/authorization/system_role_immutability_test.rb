# frozen_string_literal: true

require "test_helper"

class AuthorizationSystemRoleImmutabilityTest < ActiveSupport::TestCase
  setup { Authorization::CatalogSync.new.call }

  test "system role metadata cannot be edited archived or destroyed through models" do
    role = Authorization::Role.find_by!(key: "viewer", system: true)

    assert_predicate role, :readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { role.update!(name: "Escalated Viewer") }
    role.reload
    assert_raises(ActiveRecord::ReadOnlyRecord, ActiveRecord::RecordInvalid) do
      role.update!(archived_at: Time.current)
    end
    role.reload
    assert_raises(ActiveRecord::ReadOnlyRecord) { role.destroy! }
    assert_equal "Viewer", role.reload.name
    assert_nil role.archived_at
  end

  test "system role grants cannot be created edited or destroyed through models" do
    role = Authorization::Role.find_by!(key: "viewer", system: true)
    absent = Authorization::Permission.find_by!(key: "members.invite")
    invalid = Authorization::RolePermission.new(role: role, permission: absent)

    refute invalid.valid?
    assert_includes invalid.errors[:role], "grants are catalog managed"
    grant = role.role_permissions.first
    assert_predicate grant, :readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { grant.touch }
    assert_raises(ActiveRecord::ReadOnlyRecord) { grant.destroy! }
  end

  test "organization-owned custom roles remain mutable but cannot use reserved system keys" do
    organization = create_organization_for.organization
    custom = Authorization::Role.create!(
      organization_id: organization.id,
      key: "technical_reviewer",
      name: "Technical Reviewer",
      system: false,
      mutable: true,
      assignable_scopes: [ "organization", "project" ]
    )
    permission = Authorization::Permission.find_by!(key: "scans.read")
    grant = Authorization::RolePermission.create!(role: custom, permission: permission)

    custom.update!(name: "Senior Technical Reviewer")
    assert_equal "Senior Technical Reviewer", custom.reload.name
    assert grant.destroy!

    reserved = custom.dup
    reserved.key = "owner"
    refute reserved.valid?
    assert_raises(ActiveRecord::StatementInvalid) do
      Authorization::Role.transaction(requires_new: true) do
        Authorization::Role.insert_all!([ {
          organization_id: organization.id,
          key: "viewer",
          name: "Fake Viewer",
          system: false,
          mutable: true,
          assignable_scopes: [ "organization" ],
          created_at: Time.current,
          updated_at: Time.current
        } ])
      end
    end
  end

  test "catalog revision rows are immutable audit evidence" do
    revision = Authorization::CatalogRevision.order(:created_at).last

    assert_predicate revision, :readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { revision.update!(permission_count: 1) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { revision.destroy! }
  end
end
