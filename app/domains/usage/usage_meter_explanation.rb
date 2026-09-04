# frozen_string_literal: true

module Usage
  UsageMeterExplanation = Data.define(:key, :name, :description, :weight, :source_unit) do
    def initialize(**attributes)
      %i[key name description source_unit].each do |name|
        attributes[name] = attributes.fetch(name).to_s.freeze
      end
      super(**attributes)
      freeze
    end
  end
end
