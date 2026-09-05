# frozen_string_literal: true

require "socket"
require "uri"

module TestSupport
  module Network
    class MaliciousHttpFixture
      HOST = "127.0.0.1"
      MAX_REQUEST_BYTES = 16.kilobytes
      OVERSIZED_BODY_BYTES = 64.kilobytes

      attr_reader :host, :port, :request_headers, :requests

      def initialize
        @host = HOST
        @requests = Queue.new
        @request_headers = Queue.new
      end

      def start
        @server = TCPServer.new(HOST, 0)
        @port = @server.local_address.ip_port
        @thread = Thread.new { accept_requests }
        self
      end

      def stop
        @server&.close
        @thread&.join(1)
        @thread = nil
        @server = nil
      end

      def base_url
        raise "fixture is not running" unless port

        "http://#{HOST}:#{port}"
      end

      def request_count
        requests.size
      end

      private

      def accept_requests
        loop do
          socket = @server.accept
          handle(socket)
        end
      rescue IOError, Errno::EBADF
        nil
      end

      def handle(socket)
        request_line = socket.gets("\r\n", MAX_REQUEST_BYTES)
        return unless request_line

        method, target, = request_line.split(" ", 3)
        headers = read_headers(socket)
        path = URI.parse(target).path
        requests << { method: method, path: path }.freeze
        request_headers << headers.freeze
        status, headers, body = response_for(path)
        socket.write("HTTP/1.1 #{status}\r\n")
        headers.merge("Connection" => "close", "Content-Length" => body.bytesize.to_s).each do |key, value|
          socket.write("#{key}: #{value}\r\n")
        end
        socket.write("\r\n")
        socket.write(body)
      rescue URI::InvalidURIError
        socket.write("HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n")
      ensure
        socket.close
      end

      def read_headers(socket)
        consumed = 0
        headers = {}
        while (line = socket.gets("\r\n", MAX_REQUEST_BYTES - consumed))
          consumed += line.bytesize
          break if line == "\r\n"
          raise "request headers exceed fixture limit" if consumed >= MAX_REQUEST_BYTES

          name, value = line.split(":", 2)
          headers[name.to_s.downcase] = value.to_s.strip
        end
        headers
      end

      def response_for(path)
        case path
        when "/redirect-loop"
          [ "302 Found", { "Location" => "#{base_url}/redirect-loop" }, "" ]
        when "/redirect-private"
          [ "302 Found", { "Location" => "http://169.254.169.254/latest/meta-data" }, "" ]
        when "/oversized"
          [ "200 OK", { "Content-Type" => "text/plain" }, "x" * OVERSIZED_BODY_BYTES ]
        when "/malformed"
          [ "200 OK", { "Content-Type" => "application/xml" }, "<broken>" ]
        else
          [ "200 OK", { "Content-Type" => "text/plain" }, "local fixture" ]
        end
      end
    end
  end
end
