# frozen_string_literal: true

module TestSupport
  module PermissionAssertions
    def assert_permission_allowed(decision, reason: nil)
      assert_predicate decision, :allowed?
      assert_equal reason, decision.reason if reason
    end

    def assert_permission_denied(decision, reason: nil)
      refute_predicate decision, :allowed?
      assert_equal reason, decision.reason if reason
    end
  end
end
