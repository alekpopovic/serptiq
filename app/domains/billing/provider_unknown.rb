# frozen_string_literal: true

module Billing
  class ProviderUnknown < Shared::Public::ValidationError
    def initialize(reason_code: "billing_provider_unknown")
      super
    end
  end
end
