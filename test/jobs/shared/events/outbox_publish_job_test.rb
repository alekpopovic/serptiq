# frozen_string_literal: true

require "test_helper"

class SharedEventsOutboxPublishJobTest < ActiveSupport::TestCase
  test "publishes a committed event once and retains a bounded durable envelope" do
    owner = create_organization_for(name: "Outbox Workspace", slug: "outbox-workspace")
    event = Shared::Events::Public.record!(
      organization_id: owner.organization.id,
      aggregate_type: "BillingSubscription",
      aggregate_id: SecureRandom.uuid,
      event_type: "billing.subscription_access_changed",
      event_version: 1,
      payload: { "status" => "past_due", "access_state" => "grace" },
      idempotency_source: "outbox-job-test",
      occurred_at: Time.current
    )
    published = []
    subscriber = ->(*arguments) { published << ActiveSupport::Notifications::Event.new(*arguments).payload }

    ActiveSupport::Notifications.subscribed(subscriber, "outbox.searchops") do
      2.times { Shared::Events::OutboxPublishJob.perform_now(outbox_event_id: event.id) }
    end

    assert_equal 1, published.length
    assert_equal event.id, published.first.fetch(:event_id)
    assert_equal "billing.subscription_access_changed", published.first.fetch(:event_type)
    assert_equal 1, event.reload.attempt_count
    assert event.published?
    refute_includes event.payload.to_json, "provider"
  end

  test "database rejects malformed outbox data" do
    owner = create_organization_for(name: "Outbox Guards", slug: "outbox-guards")
    assert_raises(ActiveRecord::StatementInvalid) do
      Shared::Events::OutboxEvent.transaction(requires_new: true) do
        Shared::Events::OutboxEvent.insert!({
          organization_id: owner.organization.id,
          aggregate_type: "bad type",
          aggregate_id: SecureRandom.uuid,
          event_type: "invalid",
          event_version: 0,
          payload: {},
          idempotency_key: "raw-key",
          occurred_at: Time.current,
          created_at: Time.current,
          updated_at: Time.current
        })
      end
    end
  end

  test "subscriber failure remains unpublished and raises a retryable bounded error" do
    owner = create_organization_for(name: "Outbox Retry", slug: "outbox-retry")
    event = Shared::Events::Public.record!(
      organization_id: owner.organization.id,
      aggregate_type: "BillingSubscription",
      aggregate_id: SecureRandom.uuid,
      event_type: "billing.subscription_access_changed",
      payload: {},
      idempotency_source: "outbox-retry-test"
    )

    assert_raises(Shared::Public::TransientInfrastructureError) do
      ActiveSupport::Notifications.subscribed(->(*) { raise "consumer unavailable" }, "outbox.searchops") do
        Shared::Events::Public.publish!(outbox_event_id: event.id)
      end
    end

    event.reload
    refute event.published?
    assert_equal 1, event.attempt_count
    assert_equal "delivery_failed", event.last_error_category
  end
end
