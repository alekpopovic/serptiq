# frozen_string_literal: true

module TestSupport
  module TenantIsolationAssertions
    def assert_tenant_isolation(authorized_tenant:, foreign_tenant:, operation:)
      assert operation.call(authorized_tenant), "expected the authorized tenant operation to succeed"
      refute operation.call(foreign_tenant), "expected the cross-tenant operation to be denied"
    end

    def assert_cross_tenant_denied(error = ActiveRecord::RecordNotFound, &block)
      assert_raises(error, "expected a foreign-tenant identifier to be rejected", &block)
    end

    def assert_cross_tenant_response(expected = :not_found)
      yield
      assert_response expected
    end
  end
end
