# frozen_string_literal: true

require "securerandom"

module Shared
  module Observability
    class RequestContext
      TRACEPARENT_PATTERN = /\A[0-9a-f]{2}-([0-9a-f]{32})-[0-9a-f]{16}-[0-9a-f]{2}(?:-[^\s]+)?\z/i

      def initialize(app, runtime_attributes: nil, uuid_generator: -> { SecureRandom.uuid })
        @app = app
        @runtime_attributes = runtime_attributes
        @uuid_generator = uuid_generator
      end

      def call(environment)
        Context.reset
        request_id = correlation_id(environment) || @uuid_generator.call
        attributes = runtime_attributes.merge(
          request_id: request_id,
          trace_id: trace_id(environment["HTTP_TRACEPARENT"]) || request_id
        )
        Context.set(attributes) { @app.call(environment) }
      ensure
        Context.reset
      end

      private

      def correlation_id(environment)
        value = environment["action_dispatch.request_id"] || environment["HTTP_X_REQUEST_ID"]
        Context.normalize_correlation_id(value)
      end

      def trace_id(value)
        match = TRACEPARENT_PATTERN.match(value.to_s)
        return unless match && match[1] != "0" * 32

        match[1].downcase.freeze
      end

      def runtime_attributes
        @runtime_attributes || Observability.runtime_attributes
      end
    end
  end
end
