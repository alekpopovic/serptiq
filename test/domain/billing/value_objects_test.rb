# frozen_string_literal: true

require "test_helper"

class BillingValueObjectsTest < ActiveSupport::TestCase
  setup do
    @now = Time.utc(2026, 9, 4, 12)
    @organization_id = deterministic_uuid("organization", "billing-values")
    @plan_version_id = deterministic_uuid("plan-version", "billing-values")
  end

  test "normalized values are immutable and diagnostic serialization redacts links IDs email and payload" do
    invoice = Billing::InvoiceTransactionLink.new(
      provider: "fake", kind: "invoice", reference: "invoice-secret",
      url: "https://billing.example.test/invoices/token-secret", issued_at: @now
    )
    values = [
      Billing::Customer.new(
        provider: "fake", reference: "customer-secret", organization_id: @organization_id,
        email: "private@example.test", created_at: @now, metadata: { "private" => "provider-secret" }
      ),
      Billing::CheckoutRequest.new(
        organization_id: @organization_id, plan_version_id: @plan_version_id,
        variant_reference: "variant-secret", customer_reference: "customer-secret",
        email: "private@example.test", success_url: "https://app.example.test/success?token=secret",
        cancel_url: "https://app.example.test/cancel?token=secret", idempotency_key: "idempotency-secret"
      ),
      Billing::CheckoutResult.new(
        provider: "fake", reference: "checkout-secret",
        url: "https://billing.example.test/checkout/token-secret",
        created_at: @now, expires_at: @now + 10.minutes
      ),
      Billing::PortalLink.new(
        provider: "fake", url: "https://billing.example.test/portal/token-secret",
        created_at: @now, expires_at: @now + 10.minutes
      ),
      invoice,
      Billing::SubscriptionSnapshot.new(
        provider: "fake", customer_reference: "customer-secret",
        subscription_reference: "subscription-secret", variant_reference: "variant-secret",
        status: "active", access_state: "full", billing_interval: "monthly", currency: "EUR",
        provider_updated_at: @now, invoice_link: invoice,
        metadata: { "raw_status" => "provider-secret" }
      ),
      Billing::ProviderEvent.new(
        provider: "fake", reference: "event-secret", name: "subscription.updated",
        occurred_at: @now, customer_reference: "customer-secret",
        subscription_reference: "subscription-secret", variant_reference: "variant-secret",
        metadata: { "provider_payload" => "payload-secret" }
      ),
      Billing::VerifiedWebhook.new(
        provider: "fake", raw_body: "raw-webhook-secret", received_at: @now
      ),
      Billing::ReconciliationResult.new(
        provider: "fake", started_at: @now, finished_at: @now + 1.second,
        checked: 3, updated: 1, unchanged: 1, failed: 1,
        failure_categories: [ "timeout" ]
      )
    ]

    serialized = values.map { |value| [ value.as_json, value.inspect ] }.to_json
    assert values.all?(&:frozen?)
    %w[
      customer-secret private@example.test provider-secret variant-secret checkout-secret
      token-secret idempotency-secret invoice-secret subscription-secret event-secret
      payload-secret raw-webhook-secret
    ].each { |secret| refute_includes serialized, secret }
    assert_includes serialized, Billing::ValueNormalization::FILTERED
  end

  test "malformed lifecycle URLs metadata counts and provider references are rejected" do
    assert_raises(ArgumentError) do
      Billing::PortalLink.new(
        provider: "fake", url: "http://billing.example.test/session",
        created_at: @now, expires_at: @now + 1.minute
      )
    end
    assert_raises(ArgumentError) do
      Billing::SubscriptionSnapshot.new(
        provider: "fake", customer_reference: "customer-1", subscription_reference: "subscription-1",
        variant_reference: "variant-1", status: "active", access_state: "read_only",
        billing_interval: "monthly", currency: "EUR", provider_updated_at: @now,
        metadata: { "raw_status" => "active" }
      )
    end
    assert_raises(ArgumentError) do
      Billing::ProviderEvent.new(
        provider: "fake", reference: "event-1", name: "invented.event", occurred_at: @now
      )
    end
    assert_raises(ArgumentError) do
      Billing::ReconciliationResult.new(
        provider: "fake", started_at: @now, finished_at: @now,
        checked: 2, updated: 1, unchanged: 0, failed: 0
      )
    end
    assert_raises(ArgumentError) do
      Billing::Customer.new(
        provider: "fake", reference: "customer with spaces", organization_id: @organization_id,
        created_at: @now
      )
    end
  end
end
