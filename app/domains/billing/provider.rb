# frozen_string_literal: true

module Billing
  class Provider
    OPERATIONS = %w[
      create_customer create_checkout customer_portal fetch_subscription change_subscription
      cancel_subscription resume_subscription reconciliation_page verify_webhook identify_webhook parse_event
    ].freeze
    RAW_POLICIES = {
      "create_customer" => [ "POST", 0, "required" ],
      "create_checkout" => [ "POST", 1, "required" ],
      "customer_portal" => [ "POST", 0, "required" ],
      "fetch_subscription" => [ "GET", 2, "none" ],
      "change_subscription" => [ "PATCH", 1, "required" ],
      "cancel_subscription" => [ "DELETE", 1, "required" ],
      "resume_subscription" => [ "PATCH", 1, "required" ],
      "reconciliation_page" => [ "GET", 2, "none" ],
      "verify_webhook" => [ "LOCAL", 0, "provider_reference" ],
      "identify_webhook" => [ "LOCAL", 0, "provider_reference" ],
      "parse_event" => [ "LOCAL", 0, "provider_reference" ]
    }.freeze
    OPERATION_POLICIES = RAW_POLICIES.to_h do |operation, (method, retries, idempotency)|
      [ operation, ProviderOperationPolicy.new(
        operation: operation,
        http_method: method,
        open_timeout: 2.0,
        read_timeout: 5.0,
        max_response_bytes: 524_288,
        safe_retries: retries,
        idempotency: idempotency
      ) ]
    end.freeze

    def provider_key
      raise NotImplementedError
    end

    def supports?(operation)
      OPERATIONS.include?(operation.to_s)
    end

    def operation_policy(operation)
      OPERATION_POLICIES.fetch(operation.to_s) { raise ArgumentError, "unknown billing operation" }
    end

    OPERATIONS.each do |operation|
      define_method(operation) do |**|
        raise ProviderFailure.new(
          provider: provider_key,
          operation: operation,
          category: "unsupported_operation",
          retryable: false
        )
      end
    end
  end
end
