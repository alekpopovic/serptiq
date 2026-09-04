# frozen_string_literal: true

module Verification
  class AdapterRegistry
    def self.unconfigured
      adapters = Challenge::METHODS.to_h do |method|
        [ method, Adapters::Unconfigured.new(method: method) ]
      end
      new(adapters: adapters)
    end

    def initialize(adapters:)
      @adapters = adapters.transform_keys(&:to_s).freeze
      validate!
      freeze
    end

    def fetch(method)
      @adapters.fetch(method.to_s)
    rescue KeyError
      raise ArgumentError, "unsupported verification method"
    end

    private

    def validate!
      unknown = @adapters.keys - Challenge::METHODS
      valid = unknown.empty? && @adapters.all? do |method, adapter|
        adapter.respond_to?(:method) && adapter.method.to_s == method && adapter.respond_to?(:verify)
      end
      raise ArgumentError, "verification adapter registry is invalid" unless valid
    end
  end
end
