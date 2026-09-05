# frozen_string_literal: true

module Administration
  DeletionStageResult = Data.define(:completed, :cursor) do
    def initialize(completed:, cursor: nil)
      normalized_cursor = cursor&.to_s
      raise ArgumentError, "deletion cursor is too large" if normalized_cursor&.bytesize.to_i > 512

      super(completed: !!completed, cursor: normalized_cursor&.freeze)
      freeze
    end

    def completed?
      completed
    end

    def self.complete
      new(completed: true)
    end
  end
end
