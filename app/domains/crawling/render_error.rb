# frozen_string_literal: true

module Crawling
  class RenderError < StandardError
    attr_reader :reason_code

    def initialize(message = nil, reason_code:, transient: false)
      @reason_code = reason_code.to_s
      @transient = transient
      super(message || @reason_code.humanize)
    end

    def transient?
      @transient
    end
  end
end
