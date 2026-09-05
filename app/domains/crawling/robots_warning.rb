# frozen_string_literal: true

module Crawling
  class RobotsWarning < Data.define(:code, :line_number)
    CODE_PATTERN = /\A[a-z][a-z0-9_]{0,63}\z/

    def initialize(code:, line_number:)
      normalized = code.to_s
      raise ArgumentError, "robots warning is invalid" unless CODE_PATTERN.match?(normalized)

      super(code: normalized.freeze, line_number: Integer(line_number))
      freeze
    end

    def as_json(*)
      { "code" => code, "line_number" => line_number }
    end
  end
end
