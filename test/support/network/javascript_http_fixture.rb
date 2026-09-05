# frozen_string_literal: true

require "socket"

module TestSupport
  module Network
    class JavascriptHttpFixture
      attr_reader :port

      def start
        @server = TCPServer.new("127.0.0.1", 0)
        @port = @server.local_address.ip_port
        @thread = Thread.new { serve }
        self
      end

      def stop
        @server&.close
        @thread&.join(1)
      end

      def url
        "http://127.0.0.1:#{port}/render"
      end

      private

      def serve
        loop do
          socket = @server.accept
          Thread.new(socket) { |client| respond(client) }
        end
      rescue IOError, Errno::EBADF
        nil
      end

      def respond(socket)
        socket.gets
        while (line = socket.gets)
          break if line == "\r\n"
        end
        body = <<~HTML
          <!doctype html>
          <html><head><title>Static title</title></head>
          <body><main id="result">static</main><script>
            document.title = "Rendered fixture";
            document.querySelector("#result").textContent = "javascript executed";
            const link = document.createElement("a");
            link.href = "/client-link";
            link.textContent = "Client link";
            document.body.appendChild(link);
            console.log("fixture-ready");
          </script></body></html>
        HTML
        socket.write("HTTP/1.1 200 OK\r\n")
        socket.write("Content-Type: text/html; charset=utf-8\r\n")
        socket.write("Content-Length: #{body.bytesize}\r\n")
        socket.write("Connection: close\r\n\r\n")
        socket.write(body)
      rescue IOError, SystemCallError
        nil
      ensure
        socket.close
      end
    end
  end
end
