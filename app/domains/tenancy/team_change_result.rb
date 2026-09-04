# frozen_string_literal: true

module Tenancy
  TeamChangeResult = Data.define(:record, :changed) do
    def initialize(record:, changed:)
      super(record: record, changed: changed == true)
      freeze
    end

    def changed?
      changed
    end
  end
end
