# frozen_string_literal: true

module Identity
  class ProviderError < Shared::Public::ExternalProviderError
    CATEGORIES = %w[
      access_denied configuration credentials_revoked malformed_response rate_limited timeout unavailable
    ].freeze
    RETRYABLE_CATEGORIES = %w[rate_limited timeout unavailable].freeze
    OPERATION_PATTERN = /\A[a-z][a-z0-9_]{0,63}\z/

    attr_reader :category, :operation, :retry_after

    def initialize(category:, operation:, reason_code: nil, retry_after: nil)
      @category = category.to_s
      @operation = operation.to_s
      @retry_after = retry_after
      validate!
      super(reason_code: reason_code || "provider_#{@category}")
    end

    def retryable?
      RETRYABLE_CATEGORIES.include?(category)
    end

    def inspect
      "#<#{self.class.name} category=#{category.inspect} operation=#{operation.inspect} " \
        "retryable=#{retryable?} retry_after=#{retry_after.inspect}>"
    end

    private

    def validate!
      raise ArgumentError, "unsupported provider error category" unless CATEGORIES.include?(category)
      unless OPERATION_PATTERN.match?(operation)
        raise ArgumentError, "provider operation must be a stable label"
      end
      return if retry_after.nil? || (retry_after.is_a?(Numeric) && retry_after.finite? && retry_after >= 0)

      raise ArgumentError, "retry_after must be a nonnegative duration"
    end
  end
end
