# frozen_string_literal: true

module Properties
  module Public
    ActiveCounts = Data.define(:website, :mobile) do
      def initialize(website:, mobile:)
        super(website: Integer(website), mobile: Integer(mobile))
        freeze
      end
    end
  end
end
