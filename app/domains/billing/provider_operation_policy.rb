# frozen_string_literal: true

module Billing
  ProviderOperationPolicy = Data.define(
    :operation, :http_method, :open_timeout, :read_timeout, :max_response_bytes,
    :safe_retries, :idempotency
  ) do
    IDEMPOTENCY_POLICIES = %w[none required provider_reference].freeze

    def initialize(operation:, http_method:, open_timeout:, read_timeout:, max_response_bytes:,
      safe_retries:, idempotency:)
      operation = ValueNormalization.string!(
        operation, name: "operation", maximum: 64, pattern: ValueNormalization::KEY_PATTERN
      )
      method = http_method.to_s.upcase
      raise ArgumentError, "HTTP method is invalid" unless %w[GET POST PATCH DELETE LOCAL].include?(method)
      raise ArgumentError, "open timeout is invalid" unless open_timeout.is_a?(Numeric) && open_timeout.between?(0.1, 10)
      raise ArgumentError, "read timeout is invalid" unless read_timeout.is_a?(Numeric) && read_timeout.between?(0.1, 30)
      raise ArgumentError, "response bound is invalid" unless max_response_bytes.is_a?(Integer) &&
        max_response_bytes.between?(1024, 1_048_576)
      raise ArgumentError, "safe retries are invalid" unless safe_retries.is_a?(Integer) && safe_retries.between?(0, 3)
      idempotency = idempotency.to_s
      raise ArgumentError, "idempotency policy is invalid" unless IDEMPOTENCY_POLICIES.include?(idempotency)

      super(
        operation: operation,
        http_method: method.freeze,
        open_timeout: open_timeout,
        read_timeout: read_timeout,
        max_response_bytes: max_response_bytes,
        safe_retries: safe_retries,
        idempotency: idempotency.freeze
      )
      freeze
    end
  end
end
