# frozen_string_literal: true

module TestSupport
  class GithubCallbackAdapterFake < Identity::ProviderAdapter
    attr_reader :calls

    def initialize(configuration:, result:)
      super(configuration: configuration)
      @result = result
      @calls = []
      @mutex = Mutex.new
    end

    def authorization_request(**)
      raise UnexpectedCall, "authorization start was not expected"
    end

    def exchange_callback(input)
      @mutex.synchronize { calls << input }
      value = @result.respond_to?(:call) ? @result.call(input) : @result
      raise value if value.is_a?(Exception)

      value
    end

    class UnexpectedCall < StandardError; end
  end
end
