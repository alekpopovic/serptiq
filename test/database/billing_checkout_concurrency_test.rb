# frozen_string_literal: true

require "test_helper"

class BillingCheckoutConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  class BlockingProvider < Billing::FakeProvider
    def initialize(entered:, release:, **attributes)
      super(**attributes)
      @entered = entered
      @release = release
    end

    def create_customer(request:)
      @entered << true
      @release.pop
      super
    end
  end

  setup do
    truncate_records
    Authorization::Public.sync_catalog
    Plans::Public.sync_catalog
    @user = create_identity_user(display_name: "Concurrent Billing Owner")
    publish_all_plan_versions(user: @user)
    @owner = create_organization_for(user: @user, name: "Concurrent Billing", slug: "concurrent-billing")
    @target = Plans::PlanVersion.joins(:plan).find_by!(plans: { key: "growth" }, version: 1)
    Billing::PlanProviderMapping.create!(
      plan_version_id: @target.id,
      provider: "fake",
      environment: "test",
      currency: "EUR",
      billing_interval: "monthly",
      provider_variant_id: "variant-concurrent-growth-monthly"
    )
    @now = Time.current
    @authorization = Authorization::Public.policy(
      actor_membership: @owner.membership,
      organization: @owner.organization
    ).decision(permission_key: "billing.manage")
  end

  teardown { truncate_records }

  test "concurrent customer mapping registration converges on one tenant identity" do
    outcomes = concurrently(2.times.map do
      -> {
        Billing::Public.register_customer_mapping(
          organization_id: @owner.organization.id,
          provider: "fake",
          environment: "test",
          provider_customer_id: "customer-concurrent"
        ).reference
      }
    end)

    assert_equal [ "customer-concurrent" ], outcomes.uniq
    assert_equal 1, Billing::CustomerMapping.count
  end

  test "tenant reservation permits only one provider mutation during concurrent checkout" do
    entered = Queue.new
    release = Queue.new
    provider = BlockingProvider.new(entered: entered, release: release, clock: -> { @now })
    command = checkout_command(provider)
    first_result = Queue.new
    first = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        first_result << command.call(**checkout_attributes("concurrent-first"))
      rescue StandardError => error
        first_result << error
      end
    end
    entered.pop

    error = assert_raises(Billing::CheckoutConflict) do
      command.call(**checkout_attributes("concurrent-second"))
    end
    assert_equal "billing_checkout_already_active", error.reason_code
    release << true
    first.join

    assert_instance_of Billing::CheckoutResult, first_result.pop
    assert_equal 1, provider.calls.count { |call| call.fetch(:operation) == "create_customer" }
    assert_equal 1, provider.calls.count { |call| call.fetch(:operation) == "create_checkout" }
    assert_equal 1, Billing::CheckoutSession.count
    assert_equal 1, Billing::CustomerMapping.count
  ensure
    release << true if first&.alive?
    first&.join
  end

  test "database rejects foreign actor linkage and incomplete ready lifecycle" do
    foreign = create_organization_for(slug: "concurrent-billing-foreign")
    attributes = raw_checkout_attributes

    assert_raises(ActiveRecord::InvalidForeignKey) do
      Billing::CheckoutSession.insert_all!([
        attributes.merge(actor_membership_id: foreign.membership.id)
      ])
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Billing::CheckoutSession.insert_all!([
        attributes.merge(state: "ready", ready_at: @now)
      ])
    end
    assert_equal 0, Billing::CheckoutSession.count
  end

  private

  def checkout_command(provider)
    Billing::CreateHostedCheckout.new(
      provider: provider,
      environment: "test",
      application_origin: "https://searchops.test",
      auditor: Auditing::Public,
      clock: -> { @now }
    )
  end

  def checkout_attributes(request_key)
    {
      actor_membership: @owner.membership,
      organization: @owner.organization,
      plan_version_id: @target.id,
      currency: "EUR",
      billing_interval: "monthly",
      success_path: "/dashboard/organizations/concurrent-billing/billing/checkout/return",
      cancel_path: "/dashboard/organizations/concurrent-billing/plans",
      request_key: request_key,
      authorization: @authorization
    }
  end

  def concurrently(operations)
    start = Queue.new
    ready = Queue.new
    results = Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          results << operation.call
        rescue StandardError => error
          results << error
        end
      end
    end
    operations.length.times { ready.pop }
    operations.length.times { start << true }
    threads.each(&:join)
    values = operations.length.times.map { results.pop }
    unexpected = values.grep(Exception)
    flunk("unexpected concurrency failures: #{unexpected.map(&:full_message).join("\n")}") if unexpected.any?
    values
  end

  def raw_checkout_attributes
    {
      id: SecureRandom.uuid,
      organization_id: @owner.organization.id,
      plan_version_id: @target.id,
      actor_membership_id: @owner.membership.id,
      provider: "fake",
      environment: "test",
      currency: "EUR",
      billing_interval: "monthly",
      state: "preparing",
      idempotency_digest: "a" * 64,
      expires_at: @now + 30.minutes,
      created_at: @now,
      updated_at: @now
    }
  end

  def truncate_records
    ActiveRecord::Base.connection.execute(
      "TRUNCATE TABLE usage_meter_definitions, entitlement_definitions, plans, " \
        "organizations, users, audit_events CASCADE"
    )
  end
end
