# frozen_string_literal: true

require "net/http"
require "openssl"

module Shared
  module NetworkSafety
    class NetHttpTransport
      def get(target:, ip_address:, open_timeout:, read_timeout:, max_response_bytes:)
        http = Net::HTTP.new(target.host, target.port, nil)
        http.ipaddr = ip_address
        http.use_ssl = target.scheme == "https"
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
        http.verify_hostname = true if http.use_ssl?
        http.open_timeout = open_timeout
        http.read_timeout = read_timeout
        http.write_timeout = open_timeout

        request = Net::HTTP::Get.new(target.request_uri)
        request["Accept"] = "text/plain, text/html;q=0.9"
        request["User-Agent"] = "SearchOps-Verification/1.0"
        response = nil
        body = +"".b
        http.request(request) do |raw_response|
          content_length = raw_response["content-length"]&.to_i
          raise Error.new(reason_code: "response_too_large") if
            content_length && content_length > max_response_bytes

          raw_response.read_body do |chunk|
            raise Error.new(reason_code: "response_too_large") if
              body.bytesize + chunk.bytesize > max_response_bytes

            body << chunk
          end
          response = TransportResponse.new(
            status: raw_response.code,
            headers: {
              "content-type" => raw_response["content-type"],
              "location" => raw_response["location"]
            }.compact,
            body: body
          )
        end
        response
      rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error
        raise Error.new(reason_code: "timeout"), cause: nil
      rescue Error
        raise
      rescue IOError, SocketError, SystemCallError, OpenSSL::SSL::SSLError
        raise Error.new(reason_code: "transport_failure"), cause: nil
      end
    end
  end
end
