# frozen_string_literal: true

module Shared
  module Events
    module Public
      module_function

      def record!(**attributes)
        RecordOutboxEvent.new.call(**attributes)
      end

      def publish!(**attributes)
        PublishOutboxEvent.new.call(**attributes)
      end
    end
  end
end
