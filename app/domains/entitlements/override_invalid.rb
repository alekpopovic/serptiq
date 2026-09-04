# frozen_string_literal: true

module Entitlements
  class OverrideInvalid < Shared::Public::ValidationError
    def initialize(reason_code: "entitlement_override_invalid")
      super
    end
  end
end
