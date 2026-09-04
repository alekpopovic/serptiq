# frozen_string_literal: true

module Properties
  PropertyChangeResult = Data.define(:property, :changed) do
    def initialize(property:, changed:)
      super(property: property, changed: !!changed)
      freeze
    end

    def changed?
      changed
    end
  end
end
