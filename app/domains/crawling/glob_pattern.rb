# frozen_string_literal: true

module Crawling
  GlobPattern = Data.define(:value, :regexp) do
    MAX_BYTES = 256
    MAX_TOKENS = 12
    MAX_RECURSIVE_TOKENS = 4
    MAX_SEGMENTS = 32
    FORBIDDEN_METACHARACTERS = /[\[\]{}()|+^$\\]/

    def initialize(value:)
      pattern = value.to_s
      validate!(pattern)
      expression = compile(pattern)
      super(value: pattern.freeze, regexp: expression)
      freeze
    end

    def match?(path)
      regexp.match?(path.to_s)
    end

    private

    def validate!(pattern)
      valid = pattern.valid_encoding? && pattern == pattern.strip && pattern.start_with?("/") &&
        pattern.bytesize.between?(1, MAX_BYTES) && !pattern.match?(/[\u0000-\u001f\u007f]/) &&
        !pattern.match?(FORBIDDEN_METACHARACTERS) && !pattern.match?(/\*{3,}/) &&
        pattern.count("*") <= MAX_TOKENS && pattern.scan("**").length <= MAX_RECURSIVE_TOKENS &&
        pattern.split("/", -1).length <= MAX_SEGMENTS
      raise ArgumentError, "glob must be a bounded absolute-path pattern" unless valid
    end

    def compile(pattern)
      source = pattern.split(/(\*\*|\*)/).map do |token|
        next ".*" if token == "**"
        next "[^/]*" if token == "*"

        Regexp.escape(token)
      end.join
      Regexp.new("\\A#{source}\\z", Regexp::NOENCODING, timeout: 0.01)
    end
  end
end
