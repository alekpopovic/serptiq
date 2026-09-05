# frozen_string_literal: true

module Crawling
  class Invalid < Shared::Public::ValidationError
    attr_reader :field_errors

    def initialize(field_errors:, reason_code: "crawl_policy_invalid")
      @field_errors = field_errors.transform_keys(&:to_sym)
        .transform_values { |value| Array(value).freeze }.freeze
      super(reason_code: reason_code)
    end
  end
end
