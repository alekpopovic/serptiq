# frozen_string_literal: true

require "socket"
require "stringio"
require "uri"
require "zlib"

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
        status, headers, body, behavior = response_for(path)
        sleep(behavior.fetch(:header_delay)) if behavior[:header_delay]
        socket.write("HTTP/1.1 #{status}\r\n")
        response_headers = headers.merge("Connection" => "close")
        response_headers["Content-Length"] = body.bytesize.to_s unless behavior[:chunked]
        response_headers.each do |key, value|
          socket.write("#{key}: #{value}\r\n")
        end
        socket.write("\r\n")
        sleep(behavior.fetch(:body_delay)) if behavior[:body_delay]
        write_body(socket, method, body, behavior)
      rescue URI::InvalidURIError
        socket.write("HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n")
      rescue IOError, SystemCallError
        nil
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
          [ "302 Found", { "Location" => "#{base_url}/redirect-loop" }, "", {} ]
        when "/redirect-private"
          [ "302 Found", { "Location" => "http://169.254.169.254/latest/meta-data" }, "", {} ]
        when "/oversized"
          [ "200 OK", { "Content-Type" => "text/plain" }, "x" * OVERSIZED_BODY_BYTES, {} ]
        when "/oversized-header"
          [ "200 OK", { "Content-Type" => "text/plain", "X-Oversized" => "x" * 70.kilobytes }, "body", {} ]
        when "/gzip"
          [ "200 OK", { "Content-Type" => "text/plain; charset=UTF-8", "Content-Encoding" => "gzip" },
            gzip("compressed fixture body"), {} ]
        when "/deflate"
          [ "200 OK", { "Content-Type" => "text/plain", "Content-Encoding" => "deflate" },
            Zlib::Deflate.deflate("deflated fixture body"), {} ]
        when "/malformed-gzip"
          [ "200 OK", { "Content-Type" => "text/plain", "Content-Encoding" => "gzip" },
            "not a gzip stream", {} ]
        when "/gzip-bomb"
          [ "200 OK", { "Content-Type" => "text/plain", "Content-Encoding" => "gzip" },
            gzip("z" * 128.kilobytes), {} ]
        when "/unsupported-encoding"
          [ "200 OK", { "Content-Type" => "text/plain", "Content-Encoding" => "br" }, "encoded", {} ]
        when "/misleading"
          [ "200 OK", { "Content-Type" => "text/html" }, "%PDF-1.7\nsynthetic", {} ]
        when "/slow-headers"
          [ "200 OK", { "Content-Type" => "text/plain" }, "slow", { header_delay: 0.25 } ]
        when "/slow-body"
          [ "200 OK", { "Content-Type" => "text/plain" }, "slow", { body_delay: 0.25 } ]
        when "/chunked"
          [ "200 OK", { "Content-Type" => "text/plain", "Transfer-Encoding" => "chunked" },
            "chunked fixture body", { chunked: true } ]
        when "/oversized-chunk"
          [ "200 OK", { "Content-Type" => "text/plain", "Transfer-Encoding" => "chunked" },
            "", { chunked: true, advertised_chunk_size: 1.gigabyte } ]
        when "/malformed"
          [ "200 OK", { "Content-Type" => "application/xml" }, "<broken>", {} ]
        else
          [ "200 OK", { "Content-Type" => "text/plain" }, "local fixture", {} ]
        end
      end

      def gzip(value)
        output = StringIO.new("".b)
        writer = Zlib::GzipWriter.new(output)
        writer.write(value)
        writer.close
        output.string
      end

      def write_body(socket, method, body, behavior)
        return if method == "HEAD"

        if behavior[:advertised_chunk_size]
          socket.write("#{behavior.fetch(:advertised_chunk_size).to_s(16)}\r\n")
        elsif behavior[:chunked]
          body.bytes.each_slice(5) do |bytes|
            chunk = bytes.pack("C*")
            socket.write("#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n")
          end
          socket.write("0\r\n\r\n")
        else
          socket.write(body)
        end
      end
    end
  end
end
