# frozen_string_literal: true

module Identity
  class HttpResponse
    attr_reader :status, :headers, :body

    def initialize(status:, headers:, body:)
      @status = Integer(status)
      @headers = headers.to_h.transform_keys { |key| key.to_s.downcase.freeze }
        .transform_values { |value| value.to_s.dup.freeze }.freeze
      @body = body.to_s.b.dup.freeze
      freeze
    end

    def inspect
      "#<#{self.class.name} status=#{status} headers=#{headers.keys.sort.inspect} " \
        "body_bytes=#{body.bytesize}>"
    end
  end
end
