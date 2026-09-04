# frozen_string_literal: true

module Billing
  ConsistencyIssue = Data.define(:type, :count) do
    def initialize(type:, count:)
      normalized = type.to_s
      raise ArgumentError, "billing consistency issue is invalid" unless
        ValueNormalization::KEY_PATTERN.match?(normalized) && Integer(count).positive?

      super(type: normalized.freeze, count: Integer(count))
      freeze
    end
  end
end
