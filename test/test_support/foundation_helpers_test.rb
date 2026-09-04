# frozen_string_literal: true

require "test_helper"

class FoundationHelpersTest < ActiveSupport::TestCase
  Decision = Data.define(:allowed?, :reason)
  class FakeCurrent < ActiveSupport::CurrentAttributes
    attribute :user, :organization, :membership
  end

  test "fixed clock and deterministic UUIDs reproduce exactly" do
    first = deterministic_uuid("organization", "alpha")

    at_fixed_time do
      assert_equal TestSupport::DeterministicHelpers::FIXED_TIME, Time.current
    end
    assert_equal first, deterministic_uuid("organization", "alpha")
    refute_equal first, deterministic_uuid("organization", "beta")
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/, first)
  end

  test "signed request helper binds timestamp and exact body" do
    headers = signed_request_headers(body: "{\"event\":\"created\"}", secret: "synthetic-secret")
    changed = signed_request_headers(body: "{\"event\":\"deleted\"}", secret: "synthetic-secret")

    assert_equal TestSupport::DeterministicHelpers::FIXED_TIME.to_i.to_s,
      headers.fetch(TestSupport::CryptoHelpers::DEFAULT_TIMESTAMP_HEADER)
    assert_match(/\Asha256=[0-9a-f]{64}\z/, headers.fetch(TestSupport::CryptoHelpers::DEFAULT_SIGNATURE_HEADER))
    refute_equal headers, changed
  end

  test "encryption assertion rejects plaintext storage" do
    assert_encrypted_value(plaintext: "provider-token", ciphertext: "ciphertext:v1:abc")
    assert_raises(Minitest::Assertion) do
      assert_encrypted_value(plaintext: "provider-token", ciphertext: "provider-token")
    end
  end

  test "current tenant helper scopes and resets all context" do
    with_current_tenant(user: :user, organization: :organization, membership: :membership,
      current_class: FakeCurrent) do
      assert_equal :user, FakeCurrent.user
      assert_equal :organization, FakeCurrent.organization
      assert_equal :membership, FakeCurrent.membership
    end

    assert_nil FakeCurrent.user
    assert_nil FakeCurrent.organization
    assert_nil FakeCurrent.membership

    assert_raises(RuntimeError) do
      with_current_tenant(user: :user, organization: :organization, membership: :membership,
        current_class: FakeCurrent) { raise "synthetic failure" }
    end
    assert_nil FakeCurrent.user
    assert_nil FakeCurrent.organization
    assert_nil FakeCurrent.membership
  end

  test "tenant helper proves the foreign tenant is denied" do
    operation = ->(tenant) { tenant == :authorized }

    assert_tenant_isolation(
      authorized_tenant: :authorized,
      foreign_tenant: :foreign,
      operation: operation
    )
    assert_cross_tenant_denied(SecurityError) { raise SecurityError, "cross tenant" }
  end

  test "permission and event assertions preserve stable decision contracts" do
    assert_permission_allowed Decision.new(true, :granted), reason: :granted
    assert_permission_denied Decision.new(false, :missing_permission), reason: :missing_permission
    audit = assert_audit_event(
      events: [ { type: "membership.changed", actor_id: "user-1" } ],
      type: "membership.changed",
      attributes: { actor_id: "user-1" }
    )
    usage = assert_usage_event(
      events: [ { "type" => "crawl.page", "units" => 2 } ],
      type: "crawl.page",
      units: 2
    )

    assert_equal "membership.changed", audit.fetch(:type)
    assert_equal 2, usage.fetch("units")
  end

  test "idempotent retry assertion compares durable state" do
    state = []
    operation = -> { state << :applied unless state.include?(:applied) }

    assert_idempotent_retry(snapshot: -> { state.dup }, &operation)
    assert_equal [ :applied ], state
  end
end
