# frozen_string_literal: true

module Crawling
  class RobotsWildcardMatch
    def initialize(pattern:)
      raw = pattern.to_s.b
      @terminal = raw.end_with?("$")
      raw = raw.byteslice(0, raw.bytesize - 1) if @terminal
      @pattern = collapse_wildcards(raw)
      @pattern << "*" unless @terminal
      @pattern.freeze
    end

    def match?(value)
      candidate = value.to_s.b
      pattern_index = 0
      value_index = 0
      star_index = nil
      retry_index = 0

      while value_index < candidate.bytesize
        if literal_match?(pattern_index, candidate.getbyte(value_index))
          pattern_index += 1
          value_index += 1
        elsif wildcard?(pattern_index)
          star_index = pattern_index
          pattern_index += 1
          retry_index = value_index
        elsif star_index
          retry_index += 1
          value_index = retry_index
          pattern_index = star_index + 1
        else
          return false
        end
      end
      pattern_index += 1 while wildcard?(pattern_index)
      pattern_index == @pattern.bytesize
    end

    private

    def collapse_wildcards(value)
      value.gsub(/\*+/, "*")
    end

    def wildcard?(index)
      @pattern.getbyte(index) == 42
    end

    def literal_match?(index, byte)
      current = @pattern.getbyte(index)
      current && current != 42 && current == byte
    end
  end
end
