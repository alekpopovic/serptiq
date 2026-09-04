# frozen_string_literal: true

module Billing
  class WebhookProjectionFailure < StandardError
    attr_reader :category

    def initialize(category:, retryable:)
      @category = ValueNormalization.string!(
        category, name: "projection failure category", maximum: 64,
        pattern: ValueNormalization::KEY_PATTERN
      )
      raise ArgumentError, "projection retryability is invalid" unless [ true, false ].include?(retryable)

      @retryable = retryable
      super("Billing webhook projection failed")
    end

    def retryable?
      @retryable
    end
  end
end
