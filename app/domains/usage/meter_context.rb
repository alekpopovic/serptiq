# frozen_string_literal: true

module Usage
  MeterContext = Data.define(:window, :rate) do
    def initialize(**attributes)
      super(**attributes)
      freeze
    end
  end
end
