# frozen_string_literal: true

require "net/http"
require "openssl"
require "ipaddr"

module Shared
  module NetworkSafety
    class NetHttpTransport
      DEFAULT_USER_AGENT = "SearchOps-Verification/1.0"

      def initialize(http_factory: ->(host, port) { Net::HTTP.new(host, port, nil) })
        raise ArgumentError, "HTTP factory must implement call" unless http_factory.respond_to?(:call)

        @http_factory = http_factory
      end

      def get(destination:, open_timeout:, read_timeout:, max_response_bytes:, user_agent: nil)
        raise Error.new(reason_code: "unsafe_destination") unless destination.is_a?(ApprovedDestination)

        target = destination.target
        http = @http_factory.call(target.host, destination.port)
        if http.respond_to?(:proxy?) && http.proxy?
          raise Error.new(reason_code: "unsafe_destination", evidence: { denial_stage: "transport" })
        end

        http.ipaddr = destination.connection_ip
        http.use_ssl = target.scheme == "https"
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
        http.verify_hostname = true if http.use_ssl?
        http.open_timeout = open_timeout
        http.read_timeout = read_timeout
        http.write_timeout = open_timeout
        http.max_retries = 0

        request = Net::HTTP::Get.new(target.request_uri)
        request["Accept"] = "text/plain, text/html;q=0.9"
        request["Accept-Encoding"] = "identity"
        request["Connection"] = "close"
        request["Host"] = target.host_header
        request["User-Agent"] = normalize_user_agent(user_agent)
        response = nil
        body = +"".b
        http.request(request) do |raw_response|
          unless same_address?(http.ipaddr, destination.connection_ip)
            raise Error.new(reason_code: "unsafe_destination", evidence: { denial_stage: "transport" })
          end

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

      private

      def same_address?(left, right)
        IPAddr.new(left.to_s) == IPAddr.new(right.to_s)
      rescue IPAddr::InvalidAddressError
        false
      end

      def normalize_user_agent(value)
        candidate = value.presence || DEFAULT_USER_AGENT
        valid = candidate.is_a?(String) && candidate.bytesize.between?(1, 256) &&
          !candidate.match?(/[\u0000-\u001f\u007f]/)
        raise Error.new(reason_code: "malformed_response") unless valid

        candidate
      end
    end
  end
end
