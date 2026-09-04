# frozen_string_literal: true

module Properties
  class PropertyLimitReached < Shared::Public::QuotaError
    attr_reader :entitlement_key, :limit, :active_count

    def initialize(entitlement_key:, limit:, active_count:)
      @entitlement_key = entitlement_key
      @limit = limit
      @active_count = active_count
      super(reason_code: "property_limit_reached")
    end
  end
end
