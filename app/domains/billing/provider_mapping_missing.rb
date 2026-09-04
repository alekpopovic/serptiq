# frozen_string_literal: true

module Billing
  class ProviderMappingMissing < Shared::Public::ConflictError
    def initialize(reason_code: "billing_provider_mapping_missing")
      super
    end
  end
end
