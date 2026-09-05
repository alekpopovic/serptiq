# frozen_string_literal: true

module Crawling
  class SitemapPayloadError < StandardError
    attr_reader :reason_code

    def initialize(reason_code)
      @reason_code = reason_code.to_s.freeze
      super(@reason_code)
    end
  end
end
