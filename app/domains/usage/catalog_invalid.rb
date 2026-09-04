# frozen_string_literal: true

module Usage
  class CatalogInvalid < Shared::Public::ValidationError
    attr_reader :issues

    def initialize(issues:)
      @issues = Array(issues).map(&:to_s).freeze
      super(reason_code: "usage_catalog_invalid")
    end
  end
end
