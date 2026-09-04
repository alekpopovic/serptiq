# frozen_string_literal: true

require "test_helper"

class TenancyOrganizationContextTest < ActiveSupport::TestCase
  test "resolves slug or UUID only through the active user's membership" do
    user = create_identity_user
    accessible = create_organization_for(user: user, slug: "accessible-org")
    foreign = create_organization_for(slug: "foreign-org")

    by_slug = Tenancy::Public.resolve_organization_context(user: user, selector: "ACCESSIBLE-ORG")
    by_id = Tenancy::Public.resolve_organization_context(user: user, selector: accessible.organization.id)

    assert_equal accessible.organization, by_slug.organization
    assert_equal accessible.membership, by_slug.membership
    assert_equal by_slug, by_id
    [ foreign.organization.slug, foreign.organization.id, "missing-org" ].each do |selector|
      assert_raises(Tenancy::OrganizationAccessDenied) do
        Tenancy::Public.resolve_organization_context(user: user, selector: selector)
      end
    end
  end

  test "switcher and first-run status include only active organizations and memberships" do
    user = create_identity_user
    visible_owner = create_organization_for(name: "Visible Org", slug: "visible-org")
    visible_membership = Tenancy::Public.create_membership(actor_membership: visible_owner.membership, user: user)
    suspended_owner = create_organization_for(name: "Hidden Member", slug: "hidden-member")
    suspended_membership = Tenancy::Public.create_membership(
      actor_membership: suspended_owner.membership,
      user: user
    )
    Tenancy::Public.change_membership_status(
      actor_membership: suspended_owner.membership,
      target_membership_id: suspended_membership.id,
      operation: "suspend"
    )
    foreign = create_organization_for(name: "Foreign Org", slug: "foreign-org")

    summaries = Tenancy::Public.organization_switcher(user: user)

    assert_equal [ visible_owner.organization.id ], summaries.map(&:id)
    assert_equal [ "Visible Org" ], summaries.map(&:name)
    refute_includes summaries.map(&:id), suspended_owner.organization.id
    refute_includes summaries.map(&:id), foreign.organization.id
    assert Tenancy::Public.first_run_status(user: user).returning?

    Tenancy::Public.change_membership_status(
      actor_membership: visible_owner.membership,
      target_membership_id: visible_membership.id,
      operation: "suspend"
    )
    assert Tenancy::Public.first_run_status(user: user).no_organization?
  end

  test "Current accepts only a verified matching active pair and remains thread local" do
    first = create_organization_for(slug: "thread-one")
    second = create_organization_for(slug: "thread-two")
    entries = [
      [ first, first.membership.user ],
      [ second, second.membership.user ]
    ]
    ready = Queue.new
    release = Queue.new
    results = Queue.new

    threads = entries.map do |entry, user|
      Thread.new do
        Current.user = user
        Current.assign_tenant(organization: entry.organization, membership: entry.membership)
        ready << true
        release.pop
        results << [ Current.organization.id, Current.membership.id ]
      ensure
        Current.reset
        results << [ Current.organization, Current.membership ]
      end
    end
    2.times { ready.pop }
    2.times { release << true }
    threads.each(&:join)

    observed = 4.times.map { results.pop }
    assert_includes observed, [ first.organization.id, first.membership.id ]
    assert_includes observed, [ second.organization.id, second.membership.id ]
    assert_equal 2, observed.count([ nil, nil ])
    assert_nil Current.organization
    assert_nil Current.membership

    Current.user = first.membership.user
    assert_raises(ArgumentError) do
      Current.assign_tenant(organization: second.organization, membership: first.membership)
    end
  ensure
    Current.reset
  end
end
