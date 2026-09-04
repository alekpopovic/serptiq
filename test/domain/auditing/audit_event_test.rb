# frozen_string_literal: true

require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  setup do
    @owner = create_organization_for(slug: "audit-event-domain")
  end

  test "records immutable correlated events and filters sensitive metadata" do
    event = Shared::Observability::Context.set(
      request_id: "request-audit-123",
      trace_id: "trace-audit-123",
      job_id: "job-audit-123"
    ) do
      Auditing::Public.record!(
        organization_id: @owner.organization.id,
        actor_membership_id: @owner.membership.id,
        action: "membership.updated",
        target_type: "Membership",
        target_id: @owner.membership.id,
        result: "succeeded",
        metadata: {
          operation: "update",
          changed_fields: %w[status],
          email: "private@example.test",
          from: "private@example.test",
          ip_address: "127.0.0.1",
          user_agent: "Mozilla/5.0 secret",
          token: "raw-secret-token"
        }
      )
    end

    assert_equal "request-audit-123", event.request_id
    assert_equal "trace-audit-123", event.trace_id
    assert_equal "job-audit-123", event.job_id
    assert_equal %w[status], event.metadata.fetch("changed_fields")
    serialized = event.metadata.to_json
    refute_includes serialized, "private@example.test"
    refute_includes serialized, "127.0.0.1"
    refute_includes serialized, "Mozilla"
    refute_includes serialized, "raw-secret-token"
    assert_includes serialized, Shared::Redaction::FILTERED

    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(result: "failed") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy! }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.delete }
  end

  test "database rejects a membership actor from another organization" do
    foreign = create_organization_for(slug: "audit-event-foreign")

    assert_raises(ActiveRecord::InvalidForeignKey) do
      Auditing::AuditEvent.insert!({
        organization_id: @owner.organization.id,
        actor_type: "Membership",
        actor_membership_id: foreign.membership.id,
        action: "membership.updated",
        target_type: "Membership",
        target_id: @owner.membership.id,
        result: "succeeded",
        metadata: {},
        occurred_at: Time.current,
        created_at: Time.current
      })
    end
  end

  test "query boundary requires a matching audit read decision" do
    denied = Authorization::DecisionResult.new(
      allowed: false,
      reason_code: "permission_missing",
      permission_key: "audit_log.read",
      actor_membership_id: @owner.membership.id,
      organization_id: @owner.organization.id,
      scope_type: "Organization",
      scope_id: @owner.organization.id
    )

    assert_raises(Auditing::AccessDenied) do
      Auditing::Public.audit_page(
        organization_id: @owner.organization.id,
        authorization: denied
      )
    end
  end

  test "an unavailable audit sink rolls back an administrative mutation" do
    failure = ->(**) { raise ActiveRecord::ConnectionNotEstablished, "audit unavailable" }
    original = Auditing::Public.method(:record!)
    Auditing::Public.define_singleton_method(:record!, &failure)

    assert_no_difference -> { Tenancy::Team.where(organization_id: @owner.organization.id).count } do
      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        Tenancy::Public.create_team(actor_membership: @owner.membership, name: "Must Roll Back")
      end
    end
  ensure
    Auditing::Public.define_singleton_method(:record!) { |**attributes| original.call(**attributes) } if original
  end
end
