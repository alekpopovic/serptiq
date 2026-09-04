# frozen_string_literal: true

module Onboarding
  class Invalid < Shared::Public::ValidationError
    attr_reader :field_errors

    def initialize(field_errors:, reason_code: "onboarding_invalid")
      @field_errors = field_errors.transform_keys(&:to_sym).transform_values { |messages| Array(messages).freeze }.freeze
      super(reason_code: reason_code)
    end
  end
end
