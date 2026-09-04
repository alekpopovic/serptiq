# frozen_string_literal: true

module Tenancy
  OrganizationSummary = Data.define(:id, :name, :slug) do
    def initialize(id:, name:, slug:)
      super(id: id.to_s.freeze, name: name.to_s.freeze, slug: slug.to_s.freeze)
      freeze
    end
  end
end
