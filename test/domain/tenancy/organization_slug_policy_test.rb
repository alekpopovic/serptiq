# frozen_string_literal: true

require "test_helper"

class TenancyOrganizationSlugPolicyTest < ActiveSupport::TestCase
  test "reserved and case-conflicting slugs are rejected" do
    user = create_identity_user
    reserved = assert_raises(ActiveRecord::RecordInvalid) do
      Tenancy::Public.create_organization(user: user, name: "Reserved", slug: "Settings")
    end
    assert_includes reserved.record.errors[:slug], "is reserved"

    create_organization_for(slug: "mixed-case")
    conflict = assert_raises(ActiveRecord::RecordInvalid) do
      Tenancy::Public.create_organization(user: user, name: "Conflict", slug: "MIXED-CASE")
    end
    assert conflict.record.errors.of_kind?(:slug, :taken)
  end

  test "rename preserves the old slug and aliases cannot be claimed by another organization" do
    original = create_organization_for(slug: "original-slug")
    renamed = Tenancy::Public.update_organization(
      actor_membership: original.membership,
      name: original.organization.name,
      slug: "renamed-slug"
    )

    assert_equal "renamed-slug", renamed.slug
    assert_equal "original-slug", renamed.slug_aliases.sole.slug
    context = Tenancy::Public.resolve_organization_context(
      user: original.membership.user,
      selector: "original-slug"
    )
    assert_equal renamed, context.organization

    error = assert_raises(ActiveRecord::RecordInvalid) do
      create_organization_for(slug: "ORIGINAL-SLUG")
    end
    assert_includes error.record.errors[:slug], "has already been taken"
  end

  test "database constraints reject reserved current and alias slugs" do
    result = create_organization_for(slug: "constraint-org")

    assert_raises(ActiveRecord::StatementInvalid) do
      Tenancy::Organization.transaction(requires_new: true) do
        result.organization.update_columns(slug: "settings")
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Tenancy::OrganizationSlugAlias.transaction(requires_new: true) do
        Tenancy::OrganizationSlugAlias.insert!({
          organization_id: result.organization.id,
          slug: "billing",
          created_at: Time.current,
          updated_at: Time.current
        })
      end
    end
  end
end
