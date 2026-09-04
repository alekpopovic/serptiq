# frozen_string_literal: true

require "test_helper"

class TenancyCurrentOrganizationJobTest < ActiveJob::TestCase
  class ContextProbeJob < ApplicationJob
    class_attribute :observations, default: Queue.new

    def perform(user_id, organization_id)
      observations << [ Current.user, Current.organization, Current.membership ]
      Tenancy::Public.with_organization_context(user_id: user_id, organization_id: organization_id) do
        observations << [ Current.user.id, Current.organization.id, Current.membership.id ]
      end
      observations << [ Current.user, Current.organization, Current.membership ]
    end
  end

  setup do
    ContextProbeJob.observations = Queue.new
    Current.reset
  end

  teardown { Current.reset }

  test "job receives explicit IDs reauthorizes membership and clears every Current value" do
    result = create_organization_for(slug: "job-context")

    ContextProbeJob.perform_now(result.membership.user_id, result.organization.id)

    before, inside, after = 3.times.map { ContextProbeJob.observations.pop }
    assert_equal [ nil, nil, nil ], before
    assert_equal [ result.membership.user_id, result.organization.id, result.membership.id ], inside
    assert_equal [ nil, nil, nil ], after
    assert_nil Current.user
    assert_nil Current.organization
    assert_nil Current.membership
  end

  test "job rejects a foreign organization and still clears context" do
    accessible = create_organization_for(slug: "job-accessible")
    foreign = create_organization_for(slug: "job-foreign")

    assert_raises(Tenancy::OrganizationAccessDenied) do
      ContextProbeJob.perform_now(accessible.membership.user_id, foreign.organization.id)
    end

    assert_nil Current.user
    assert_nil Current.organization
    assert_nil Current.membership
  end

  test "job reauthorization rejects a suspended or removed membership" do
    owner = create_organization_for(slug: "job-membership-lifecycle")
    target_user = create_identity_user(display_name: "Job Target")
    target = Tenancy::Public.create_membership(actor_membership: owner.membership, user: target_user)

    Tenancy::Public.change_membership_status(
      actor_membership: owner.membership,
      target_membership_id: target.id,
      operation: "suspend"
    )
    assert_raises(Tenancy::OrganizationAccessDenied) do
      ContextProbeJob.perform_now(target_user.id, owner.organization.id)
    end

    Tenancy::Public.change_membership_status(
      actor_membership: owner.membership,
      target_membership_id: target.id,
      operation: "remove"
    )
    assert_raises(Tenancy::OrganizationAccessDenied) do
      ContextProbeJob.perform_now(target_user.id, owner.organization.id)
    end
    assert_nil Current.organization
    assert_nil Current.membership
  end
end
