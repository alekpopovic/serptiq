# frozen_string_literal: true

module Shared
  module Errors
    Definition = Data.define(:category, :public_code, :http_status, :public_message, :retryable)
    HttpResponse = Data.define(:category, :public_code, :http_status, :public_message, :expected)

    CATALOG = {
      validation: Definition.new("validation", "validation_failed", 422,
        "The request could not be processed.", false),
      authentication: Definition.new("authentication", "authentication_required", 401,
        "Sign in is required.", false),
      authorization: Definition.new("authorization", "authorization_denied", 403,
        "You do not have permission to perform this action.", false),
      entitlement: Definition.new("entitlement", "entitlement_required", 403,
        "This feature is not enabled for this organization.", false),
      quota: Definition.new("quota", "quota_exceeded", 429,
        "The available usage limit has been reached.", false),
      rate_limit: Definition.new("rate_limit", "rate_limited", 429,
        "Too many requests. Please try again later.", true),
      conflict: Definition.new("conflict", "resource_conflict", 409,
        "The request conflicts with the current resource state.", false),
      external_provider: Definition.new("external_provider", "external_provider_failed", 502,
        "An external service could not complete the request.", false),
      transient_infrastructure: Definition.new("transient_infrastructure", "service_temporarily_unavailable", 503,
        "The service is temporarily unavailable. Please try again.", true),
      unsafe_destination: Definition.new("unsafe_destination", "unsafe_destination", 422,
        "The destination is not allowed.", false),
      internal_fault: Definition.new("internal_fault", "internal_error", 500,
        "Something went wrong. Please try again.", false)
    }.freeze

    class Base < StandardError
      REASON_CODE_PATTERN = /\A[a-z][a-z0-9_]{0,63}\z/

      class << self
        def error_category(value = nil)
          @error_category = value if value
          return @error_category if @error_category
          return superclass.error_category if superclass.respond_to?(:error_category)

          raise NotImplementedError, "error category is not defined"
        end
      end

      attr_reader :reason_code

      def initialize(message = nil, reason_code: nil)
        @reason_code = normalize_reason_code(reason_code)
        super(message || definition.public_message)
      end

      def definition
        CATALOG.fetch(self.class.error_category)
      end

      private

      def normalize_reason_code(value)
        return if value.nil?

        normalized = value.to_s
        raise ArgumentError, "reason_code must be a stable snake_case identifier" unless REASON_CODE_PATTERN.match?(normalized)

        normalized.freeze
      end
    end

    class ValidationError < Base
      error_category :validation
    end

    class AuthenticationError < Base
      error_category :authentication
    end

    class AuthorizationError < Base
      error_category :authorization
    end

    class EntitlementError < Base
      error_category :entitlement
    end

    class QuotaError < Base
      error_category :quota
    end

    class RateLimitError < Base
      error_category :rate_limit
    end

    class ConflictError < Base
      error_category :conflict
    end

    class ExternalProviderError < Base
      error_category :external_provider
    end

    class TransientInfrastructureError < Base
      error_category :transient_infrastructure
    end

    class UnsafeDestinationError < Base
      error_category :unsafe_destination
    end

    class InternalFault < Base
      error_category :internal_fault
    end

    module_function

    def http_response_for(error)
      expected = error.is_a?(Base) && !error.is_a?(InternalFault)
      definition = error.is_a?(Base) ? error.definition : CATALOG.fetch(:internal_fault)
      HttpResponse.new(
        definition.category,
        definition.public_code,
        definition.http_status,
        definition.public_message,
        expected
      )
    end

    def cause_classes(error, limit: 5)
      classes = []
      current = error.cause
      while current && classes.length < limit
        class_name = current.class.name.to_s
        classes << (class_name.empty? ? "AnonymousError" : class_name)
        current = current.cause
      end
      classes.freeze
    end
  end
end
