# frozen_string_literal: true

module TestSupport
  class ProviderFake
    class UnexpectedCall < StandardError; end

    attr_reader :calls

    def initialize(**scripts)
      @scripts = scripts.transform_keys(&:to_sym).transform_values { |responses| Array(responses).dup }
      @calls = []
    end

    def invoke(operation, **request)
      operation = operation.to_sym
      responses = @scripts.fetch(operation) do
        raise UnexpectedCall, "provider operation #{operation.inspect} was not scripted"
      end
      raise UnexpectedCall, "provider operation #{operation.inspect} exhausted its script" if responses.empty?

      calls << { operation: operation, request: request.deep_dup }.freeze
      response = responses.shift
      raise response if response.is_a?(Exception)

      response.respond_to?(:call) ? response.call(request) : response.deep_dup
    end

    def assert_exhausted!
      remaining = @scripts.filter_map { |operation, responses| operation unless responses.empty? }
      raise UnexpectedCall, "unused provider scripts: #{remaining.join(", ")}" if remaining.any?

      true
    end
  end
end
