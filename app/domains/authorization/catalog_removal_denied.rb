# frozen_string_literal: true

module Authorization
  class CatalogRemovalDenied < Shared::Public::ConflictError
    attr_reader :keys

    def initialize(keys:)
      @keys = Array(keys).map(&:to_s).sort.freeze
      super(reason_code: "authorization_catalog_removal_denied")
    end
  end
end
