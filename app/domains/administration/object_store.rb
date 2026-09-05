# frozen_string_literal: true

module Administration
  class ObjectStore
    DeleteResult = Data.define(:completed, :cursor) do
      def initialize(completed:, cursor: nil)
        super(completed: !!completed, cursor: cursor&.to_s&.freeze)
        freeze
      end

      def completed?
        completed
      end
    end

    def delete_prefix(prefix:, cursor: nil)
      raise NotImplementedError
    end

    def objects_remaining?(prefix:)
      raise NotImplementedError
    end
  end

  class EmptyObjectStore < ObjectStore
    def delete_prefix(prefix:, cursor: nil)
      DeleteResult.new(completed: true)
    end

    def objects_remaining?(prefix:)
      false
    end
  end

  class ObjectStoreUnavailable < Shared::Public::TransientJobError
    error_category :external_provider
  end
end
