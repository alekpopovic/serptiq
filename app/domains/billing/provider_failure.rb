# frozen_string_literal: true

module Billing
  class ProviderFailure < Shared::Public::ExternalProviderError
    CATEGORIES = %w[
      authentication authorization validation not_found rate_limited timeout unavailable malformed_response
      signature_invalid unsupported_operation
    ].freeze

    attr_reader :provider, :operation, :category, :retry_after

    def initialize(provider:, operation:, category:, retryable:, retry_after: nil)
      @provider = ValueNormalization.string!(
        provider, name: "provider", maximum: 32, pattern: ValueNormalization::PROVIDER_PATTERN
      )
      @operation = ValueNormalization.string!(
        operation, name: "operation", maximum: 64, pattern: ValueNormalization::KEY_PATTERN
      )
      @category = category.to_s
      raise ArgumentError, "provider failure category is invalid" unless CATEGORIES.include?(@category)
      raise ArgumentError, "retryable must be boolean" unless [ true, false ].include?(retryable)
      if retry_after && (!retry_after.is_a?(Integer) || retry_after <= 0 || retry_after > 86_400)
        raise ArgumentError, "retry_after is invalid"
      end

      @retryable = retryable
      @retry_after = retry_after
      super(reason_code: "billing_provider_#{@category}")
    end

    def retryable?
      @retryable
    end

    def inspect
      "#<#{self.class.name} provider=#{provider.inspect} operation=#{operation.inspect} " \
        "category=#{category.inspect} retryable=#{retryable?}>"
    end
  end
end
