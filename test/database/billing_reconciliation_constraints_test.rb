# frozen_string_literal: true

require "test_helper"

class BillingReconciliationConstraintsTest < ActiveSupport::TestCase
  setup do
    Current.reset
    sync_usage_catalog
    @owner, = create_subscribed_usage_organization(slug: "reconciliation-constraints")
    @foreign = create_organization_for(slug: "reconciliation-constraints-foreign")
    @subscription = Billing::Subscription.current.find_by!(organization_id: @owner.organization.id)
    @now = Time.current.change(usec: 0)
  end

  teardown { Current.reset }

  test "composite foreign key rejects a reconciliation attached to another tenant" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Billing::ReconciliationRun.transaction(requires_new: true) do
        Billing::ReconciliationRun.insert!(run_attributes.merge(organization_id: @foreign.organization.id))
      end
    end
  end

  test "database rejects invalid lifecycle and oversized provider evidence" do
    assert_database_rejects(state: "matched", attempt_count: 0)
    assert_database_rejects(provider_snapshot: { "observation" => "x" * 9.kilobytes })
    assert_database_rejects(difference_fields: { "status" => true })
  end

  test "support grants enforce the permission allowlist and revocation order" do
    user = create_identity_user

    assert_raises(ActiveRecord::StatementInvalid) do
      Billing::SupportAccessGrant.transaction(requires_new: true) do
        Billing::SupportAccessGrant.insert!({
          user_id: user.id,
          permission: "billing_support.superuser",
          granted_at: @now,
          created_at: @now,
          updated_at: @now
        })
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Billing::SupportAccessGrant.transaction(requires_new: true) do
        Billing::SupportAccessGrant.insert!({
          user_id: user.id,
          permission: "billing_support.read",
          granted_at: @now,
          revoked_at: @now - 1.second,
          created_at: @now,
          updated_at: @now
        })
      end
    end
  end

  private

  def run_attributes
    {
      organization_id: @owner.organization.id,
      subscription_id: @subscription.id,
      provider: "fake",
      environment: "test",
      source: "scheduled",
      state: "queued",
      provider_snapshot: {},
      difference_fields: [],
      requested_at: @now,
      attempt_count: 0,
      lock_version: 0,
      created_at: @now,
      updated_at: @now
    }
  end

  def assert_database_rejects(attributes)
    assert_raises(ActiveRecord::StatementInvalid) do
      Billing::ReconciliationRun.transaction(requires_new: true) do
        Billing::ReconciliationRun.insert!(run_attributes.merge(attributes))
      end
    end
  end
end
