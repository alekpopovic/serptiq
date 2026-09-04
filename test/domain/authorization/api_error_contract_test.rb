# frozen_string_literal: true

require "test_helper"

class AuthorizationApiErrorContractTest < ActiveSupport::TestCase
  test "returns a stable bounded denial payload without tenant or resource identifiers" do
    decision = Authorization::DecisionResult.new(
      allowed: false,
      reason_code: "permission_missing",
      permission_key: "teams.manage",
      actor_membership_id: "secret-membership-id",
      organization_id: "secret-organization-id",
      scope_type: "Project",
      scope_id: "secret-project-id"
    )

    payload = Authorization::Public.api_error(
      Authorization::AccessDenied.new(decision: decision),
      request_id: "request-123"
    )

    assert_equal({
      error: {
        code: "authorization_denied",
        reason_code: "permission_missing",
        request_id: "request-123"
      }
    }, payload)
    refute_includes payload.to_json, "secret-organization-id"
    refute_includes payload.to_json, "secret-membership-id"
    refute_includes payload.to_json, "secret-project-id"
    assert_predicate payload, :frozen?
    assert_predicate payload.fetch(:error), :frozen?
  end

  test "rejects unrelated exceptions" do
    assert_raises(ArgumentError) do
      Authorization::Public.api_error(StandardError.new("no"), request_id: "request-123")
    end
  end
end
