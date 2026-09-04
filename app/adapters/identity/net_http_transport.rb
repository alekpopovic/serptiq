# frozen_string_literal: true

require "net/http"
require "openssl"

module Identity
  class NetHttpTransport
    def initialize(http_factory: nil)
      @http_factory = http_factory || ->(uri) { Net::HTTP.new(uri.host, uri.port, nil) }
    end

    def call(method:, uri:, headers:, body:, open_timeout:, read_timeout:, max_response_bytes:)
      http = @http_factory.call(uri)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout
      http.write_timeout = read_timeout
      http.max_retries = 0
      request = request_class(method).new(uri.request_uri, headers)
      request.body = body if body

      http.start do |client|
        client.request(request) do |response|
          return HttpResponse.new(
            status: response.code,
            headers: response.each_header.to_h,
            body: read_bounded_body(response, max_response_bytes)
          )
        end
      end
    end

    private

    def request_class(method)
      case method.to_sym
      when :get then Net::HTTP::Get
      when :post then Net::HTTP::Post
      else raise ArgumentError, "unsupported HTTP method"
      end
    end

    def read_bounded_body(response, maximum)
      content_length = response["content-length"]
      raise ResponseTooLarge if content_length && Integer(content_length, 10) > maximum

      body = +"".b
      response.read_body do |chunk|
        raise ResponseTooLarge if body.bytesize + chunk.bytesize > maximum

        body << chunk
      end
      body
    rescue ArgumentError
      raise ResponseTooLarge
    end
  end
end
