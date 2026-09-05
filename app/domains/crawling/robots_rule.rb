# frozen_string_literal: true

module Crawling
  class RobotsRule < Data.define(:directive, :pattern, :normalized_pattern, :specificity, :line_number)
    DIRECTIVES = %w[allow disallow].freeze

    def initialize(**attributes)
      directive = attributes.fetch(:directive).to_s
      raise ArgumentError, "robots directive is invalid" unless DIRECTIVES.include?(directive)

      super(
        directive: directive.freeze,
        pattern: attributes.fetch(:pattern).to_s.freeze,
        normalized_pattern: attributes.fetch(:normalized_pattern).to_s.freeze,
        specificity: Integer(attributes.fetch(:specificity)),
        line_number: Integer(attributes.fetch(:line_number))
      )
      freeze
    end

    def allow?
      directive == "allow"
    end

    def match?(request_target)
      RobotsWildcardMatch.new(pattern: normalized_pattern).match?(request_target)
    end

    def as_json(*)
      {
        "directive" => directive,
        "pattern" => pattern,
        "normalized_pattern" => normalized_pattern,
        "specificity" => specificity,
        "line_number" => line_number
      }
    end
  end
end
