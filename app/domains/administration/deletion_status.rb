# frozen_string_literal: true

module Administration
  DeletionStatus = Data.define(:state, :hold_until, :current_stage, :cancelable, :last_error_category) do
    def initialize(**attributes)
      %i[state current_stage last_error_category].each do |name|
        attributes[name] = attributes[name]&.to_s&.freeze
      end
      attributes[:cancelable] = !!attributes.fetch(:cancelable)
      super(**attributes)
      freeze
    end
  end
end
