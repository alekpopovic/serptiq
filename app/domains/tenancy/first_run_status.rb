# frozen_string_literal: true

module Tenancy
  FirstRunStatus = Data.define(:kind) do
    KINDS = %i[no_organization invited returning].freeze

    def initialize(kind:)
      normalized = kind.to_sym
      raise ArgumentError, "unsupported first-run status" unless KINDS.include?(normalized)

      super(kind: normalized)
      freeze
    end

    KINDS.each do |candidate|
      define_method("#{candidate}?") { kind == candidate }
    end
  end
end
