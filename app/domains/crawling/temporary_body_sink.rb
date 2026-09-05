# frozen_string_literal: true

require "tempfile"

module Crawling
  class TemporaryBodySink
    def initialize
      @file = Tempfile.new([ "searchops-crawl", ".body" ], binmode: true)
      @finished = false
    end

    def write(chunk)
      raise IOError, "crawl body sink is closed" if @file.closed?

      @file.write(chunk)
    end

    def finish
      return @file if @finished

      @file.flush
      @file.rewind
      @finished = true
      @file
    end

    def abort
      @file.close!
    end
  end
end
