# frozen_string_literal: true

module Plans
  CatalogValueChange = Data.define(:path, :before, :after) do
    def initialize(path:, before:, after:)
      super(path: path.to_s.freeze, before: immutable(before), after: immutable(after))
      freeze
    end

    private

    def immutable(value)
      value.is_a?(String) ? value.dup.freeze : value
    end
  end
end
