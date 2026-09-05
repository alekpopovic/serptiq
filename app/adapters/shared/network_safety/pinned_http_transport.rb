# frozen_string_literal: true

require "digest"
require "openssl"
require "socket"
require "zlib"

module Shared
  module NetworkSafety
    class PinnedHttpTransport
      HEADER_FIELD_LIMIT = 100
      READ_CHUNK_BYTES = 16.kilobytes
      SNIFF_BYTES = 512
      METHODS = { get: "GET", head: "HEAD" }.freeze

      class NullSink
        def write(_chunk); end
      end

      def initialize(monotonic_clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
        socket_factory: ->(address, port, timeout) { Socket.tcp(address, port, connect_timeout: timeout) },
        ssl_context_factory: -> { OpenSSL::SSL::SSLContext.new })
        @clock = monotonic_clock
        @socket_factory = socket_factory
        @ssl_context_factory = ssl_context_factory
      end

      def request(destination:, method:, limits:, user_agent:, sink: NullSink.new, cancellation: -> { false })
        validate_request!(destination, method, limits, user_agent, sink, cancellation)
        target = destination.target
        verb = METHODS.fetch(method.to_sym)
        started = @clock.call
        total_deadline = started + limits.total_timeout
        check_cancellation!(cancellation)
        raw_socket, connected_at = connect(destination, limits, total_deadline)
        io, tls_finished_at = secure_socket(
          raw_socket, target, limits, total_deadline, connected_at, cancellation
        )
        write_request(io, target, verb, user_agent, total_deadline, cancellation)
        header_started = @clock.call
        reader = BufferedReader.new(io: io, clock: @clock, cancellation: cancellation)
        status, raw_headers, header_bytes = read_response_head(reader, limits, total_deadline)
        header_finished = @clock.call
        body_result = read_response_body(
          reader: reader,
          status: status,
          method: verb,
          headers: raw_headers,
          limits: limits,
          total_deadline: total_deadline,
          sink: sink,
          cancellation: cancellation
        )
        finished = @clock.call
        BoundedTransportResponse.new(
          status: status,
          headers: normalized_headers(raw_headers),
          header_bytes: header_bytes,
          **body_result,
          timings: {
            connect_ms: milliseconds(connected_at - started),
            tls_ms: milliseconds(tls_finished_at - connected_at),
            header_ms: milliseconds(header_finished - header_started),
            body_ms: milliseconds(finished - header_finished),
            total_ms: milliseconds(finished - started)
          }
        )
      rescue Error
        raise
      rescue SocketError, SystemCallError, IOError
        raise safe_error("transport_failure", started), cause: nil
      ensure
        io&.close
        raw_socket&.close unless raw_socket&.closed?
      end

      private

      def validate_request!(destination, method, limits, user_agent, sink, cancellation)
        valid = destination.is_a?(ApprovedDestination) && METHODS.key?(method.to_sym) &&
          limits.is_a?(TransportLimits) && sink.respond_to?(:write) && cancellation.respond_to?(:call) &&
          user_agent.is_a?(String) && user_agent.bytesize.between?(1, 256) &&
          !user_agent.match?(/[\u0000-\u001f\u007f]/)
        raise ArgumentError, "bounded HTTP request is invalid" unless valid
      rescue NoMethodError
        raise ArgumentError, "bounded HTTP request is invalid", cause: nil
      end

      def connect(destination, limits, total_deadline)
        total_remaining = remaining(total_deadline, "total_timeout")
        timeout_code = total_remaining <= limits.connect_timeout ? "total_timeout" : "connect_timeout"
        timeout = [ limits.connect_timeout, total_remaining ].min
        socket = @socket_factory.call(destination.connection_ip, destination.port, timeout)
        [ socket, @clock.call ]
      rescue Errno::ETIMEDOUT, IO::TimeoutError
        raise safe_error(timeout_code || "connect_timeout"), cause: nil
      end

      def secure_socket(socket, target, limits, total_deadline, connected_at, cancellation)
        return [ socket, connected_at ] unless target.scheme == "https"

        context = @ssl_context_factory.call
        context.set_params
        context.verify_mode = OpenSSL::SSL::VERIFY_PEER
        context.min_version = OpenSSL::SSL::TLS1_2_VERSION
        ssl = OpenSSL::SSL::SSLSocket.new(socket, context)
        ssl.hostname = target.host
        ssl.sync_close = true
        deadline = [ total_deadline, @clock.call + limits.tls_timeout ].min
        nonblocking_connect(
          ssl, deadline, timeout_code(deadline, total_deadline, "tls_timeout"), cancellation
        )
        ssl.post_connection_check(target.host)
        [ ssl, @clock.call ]
      rescue OpenSSL::SSL::SSLError => error
        category = error.message.include?("certificate verify failed") ||
          error.message.include?("hostname") ? "tls_certificate" : "tls_protocol"
        raise safe_error(category, connected_at), cause: nil
      end

      def nonblocking_connect(ssl, deadline, timeout_code, cancellation)
        loop do
          case ssl.connect_nonblock(exception: false)
          when :wait_readable then wait_for(ssl, :read, deadline, timeout_code, cancellation)
          when :wait_writable then wait_for(ssl, :write, deadline, timeout_code, cancellation)
          else return
          end
        end
      end

      def write_request(io, target, method, user_agent, total_deadline, cancellation)
        request = +"#{method} #{target.request_uri} HTTP/1.1\r\n"
        request << "Host: #{target.host_header}\r\n"
        request << "User-Agent: #{user_agent}\r\n"
        request << "Accept: */*\r\n"
        request << "Accept-Encoding: gzip, deflate, identity\r\n"
        request << "Connection: close\r\n\r\n"
        offset = 0
        while offset < request.bytesize
          check_cancellation!(cancellation)
          remaining(total_deadline, "total_timeout")
          written = io.write_nonblock(request.byteslice(offset..), exception: false)
          if written == :wait_readable
            wait_for(io, :read, total_deadline, "total_timeout", cancellation)
          elsif written == :wait_writable
            wait_for(io, :write, total_deadline, "total_timeout", cancellation)
          else
            offset += written
          end
        end
      end

      def read_response_head(reader, limits, total_deadline)
        deadline = [ total_deadline, @clock.call + limits.header_timeout ].min
        header_bytes = 0
        interim_count = 0
        loop do
          status_line = reader.read_line(
            deadline: deadline,
            maximum: limits.max_header_bytes - header_bytes,
            timeout_code: timeout_code(deadline, total_deadline, "header_timeout")
          )
          header_bytes += status_line.bytesize
          match = /\AHTTP\/1\.[01] ([1-5][0-9]{2})(?: [^\r\n]*)?\r\n\z/.match(status_line)
          raise Error.new(reason_code: "malformed_response") unless match

          status = Integer(match[1])
          headers, consumed = read_header_fields(reader, deadline, limits.max_header_bytes - header_bytes,
            total_deadline)
          header_bytes += consumed
          return [ status, headers, header_bytes ] unless status.between?(100, 199) && status != 101

          interim_count += 1
          raise Error.new(reason_code: "malformed_response") if interim_count > 4
        end
      rescue HeaderLimitError
        raise Error.new(reason_code: "header_too_large", evidence: { header_byte_count: limits.max_header_bytes })
      end

      def read_header_fields(reader, deadline, maximum, total_deadline)
        headers = Hash.new { |hash, key| hash[key] = [] }
        consumed = 0
        fields = 0
        loop do
          line = reader.read_line(
            deadline: deadline,
            maximum: maximum - consumed,
            timeout_code: timeout_code(deadline, total_deadline, "header_timeout")
          )
          consumed += line.bytesize
          break if line == "\r\n"

          fields += 1
          raise HeaderLimitError if fields > HEADER_FIELD_LIMIT || line.start_with?(" ", "\t")

          match = /\A([!#$%&'*+.^_`|~0-9A-Za-z-]+):[ \t]*([^\r\n]*)\r\n\z/.match(line)
          raise Error.new(reason_code: "malformed_response") unless match

          value = match[2]
          raise Error.new(reason_code: "malformed_response") if value.match?(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/)

          headers[match[1].downcase] << value
        end
        [ headers.transform_values(&:freeze).freeze, consumed ]
      end

      def read_response_body(reader:, status:, method:, headers:, limits:, total_deadline:, sink:, cancellation:)
        decoder = Decoder.new(headers: headers, limits: limits, sink: sink, cancellation: cancellation)
        unless method == "HEAD" || status.between?(100, 199) || [ 204, 304 ].include?(status)
          deadline = [ total_deadline, @clock.call + limits.body_timeout ].min
          transfer_encoding = joined_header(headers, "transfer-encoding")
          content_length = content_length(headers)
          if transfer_encoding.present? && content_length
            raise Error.new(reason_code: "malformed_response")
          elsif transfer_encoding.present?
            raise Error.new(reason_code: "malformed_response") unless transfer_encoding.downcase == "chunked"

            read_chunked_body(reader, decoder, deadline, total_deadline, limits)
          elsif content_length
            raise Error.new(reason_code: "response_too_large", evidence: { compressed_byte_count: content_length }) if
              content_length > limits.max_body_bytes

            read_sized_body(reader, decoder, content_length, deadline, total_deadline)
          else
            read_body_to_eof(reader, decoder, deadline, total_deadline)
          end
        end
        decoder.finish
      end

      def read_chunked_body(reader, decoder, deadline, total_deadline, limits)
        loop do
          line = reader.read_line(
            deadline: deadline,
            maximum: 256,
            timeout_code: timeout_code(deadline, total_deadline, "body_timeout")
          )
          match = /\A([0-9A-Fa-f]{1,16})(?:;[^\r\n]{0,200})?\r\n\z/.match(line)
          raise Error.new(reason_code: "malformed_response") unless match

          size = Integer(match[1], 16)
          if size.zero?
            read_trailers(reader, deadline, total_deadline, limits.max_header_bytes)
            break
          end
          if size > limits.max_body_bytes - decoder.compressed_bytes
            raise Error.new(
              reason_code: "response_too_large",
              evidence: { compressed_byte_count: limits.max_body_bytes }
            )
          end
          read_sized_body(reader, decoder, size, deadline, total_deadline)
          ending = reader.read_exact(
            2,
            deadline: deadline,
            timeout_code: timeout_code(deadline, total_deadline, "body_timeout")
          )
          raise Error.new(reason_code: "malformed_response") unless ending == "\r\n"
        end
      rescue HeaderLimitError
        raise Error.new(reason_code: "header_too_large")
      end

      def read_trailers(reader, deadline, total_deadline, maximum)
        consumed = 0
        fields = 0
        loop do
          line = reader.read_line(
            deadline: deadline,
            maximum: maximum - consumed,
            timeout_code: timeout_code(deadline, total_deadline, "body_timeout")
          )
          consumed += line.bytesize
          break if line == "\r\n"

          fields += 1
          raise HeaderLimitError if fields > HEADER_FIELD_LIMIT || !line.include?(":")
        end
      end

      def read_sized_body(reader, decoder, size, deadline, total_deadline)
        remaining_bytes = size
        while remaining_bytes.positive?
          chunk = reader.read_exact(
            [ remaining_bytes, READ_CHUNK_BYTES ].min,
            deadline: deadline,
            timeout_code: timeout_code(deadline, total_deadline, "body_timeout")
          )
          decoder.write(chunk)
          remaining_bytes -= chunk.bytesize
        end
      end

      def read_body_to_eof(reader, decoder, deadline, total_deadline)
        while (chunk = reader.read_some(
          maximum: READ_CHUNK_BYTES,
          deadline: deadline,
          timeout_code: timeout_code(deadline, total_deadline, "body_timeout")
        ))
          decoder.write(chunk)
        end
      end

      def content_length(headers)
        values = headers.fetch("content-length", []).flat_map { |value| value.split(",") }.map(&:strip)
        return if values.empty?
        raise Error.new(reason_code: "malformed_response") unless
          values.all? { |value| value.match?(/\A[0-9]{1,20}\z/) } && values.uniq.one?

        Integer(values.first)
      end

      def normalized_headers(headers)
        BoundedTransportResponse::HEADER_NAMES.to_h do |name|
          values = headers.fetch(name, [])
          [ name, values.join(", ") ]
        end.reject { |_name, value| value.empty? }
      end

      def joined_header(headers, name)
        headers.fetch(name, []).join(", ").strip
      end

      def timeout_code(deadline, total_deadline, stage_code)
        deadline == total_deadline ? "total_timeout" : stage_code
      end

      def wait_for(io, direction, deadline, timeout_code, cancellation = -> { false })
        loop do
          check_cancellation!(cancellation)
          timeout = [ remaining(deadline, timeout_code), 0.1 ].min
          ready = if direction == :read
            IO.select([ io ], nil, nil, timeout)
          else
            IO.select(nil, [ io ], nil, timeout)
          end
          return if ready
        end
      end

      def remaining(deadline, timeout_code)
        value = deadline - @clock.call
        raise Error.new(reason_code: timeout_code) unless value.positive?

        value
      end

      def check_cancellation!(cancellation)
        raise Error.new(reason_code: "canceled") if cancellation.call == true
      end

      def safe_error(reason_code, started = nil)
        duration = started ? milliseconds(@clock.call - started) : nil
        Error.new(reason_code: reason_code, evidence: { duration_ms: duration }.compact)
      end

      def milliseconds(seconds)
        (seconds * 1000).round.clamp(0, 600_000)
      end

      class HeaderLimitError < StandardError; end

      class BufferedReader
        def initialize(io:, clock:, cancellation:)
          @io = io
          @clock = clock
          @cancellation = cancellation
          @buffer = +"".b
        end

        def read_line(deadline:, maximum:, timeout_code:)
          raise HeaderLimitError unless maximum.positive?

          loop do
            if (index = @buffer.index("\n"))
              length = index + 1
              raise HeaderLimitError if length > maximum

              return @buffer.slice!(0, length)
            end
            raise HeaderLimitError if @buffer.bytesize >= maximum

            chunk = read_nonblock(deadline, timeout_code)
            raise Error.new(reason_code: "malformed_response") unless chunk

            @buffer << chunk
          end
        end

        def read_exact(size, deadline:, timeout_code:)
          while @buffer.bytesize < size
            chunk = read_nonblock(deadline, timeout_code)
            raise Error.new(reason_code: "malformed_response") unless chunk

            @buffer << chunk
          end
          @buffer.slice!(0, size)
        end

        def read_some(maximum:, deadline:, timeout_code:)
          return @buffer.slice!(0, [ maximum, @buffer.bytesize ].min) unless @buffer.empty?

          read_nonblock(deadline, timeout_code, maximum)
        end

        private

        def read_nonblock(deadline, timeout_code, maximum = READ_CHUNK_BYTES)
          loop do
            raise Error.new(reason_code: "canceled") if @cancellation.call == true

            remaining = deadline - @clock.call
            raise Error.new(reason_code: timeout_code) unless remaining.positive?

            value = @io.read_nonblock(maximum, exception: false)
            case value
            when :wait_readable
              next unless IO.select([ @io ], nil, nil, [ remaining, 0.1 ].min)
            when :wait_writable
              next unless IO.select(nil, [ @io ], nil, [ remaining, 0.1 ].min)
            when nil
              return
            else
              return value
            end
          end
        end
      end

      class Decoder
        attr_reader :compressed_bytes

        def initialize(headers:, limits:, sink:, cancellation:)
          @limits = limits
          @sink = sink
          @cancellation = cancellation
          @compressed_bytes = 0
          @decoded_bytes = 0
          @digest = Digest::SHA256.new
          @sample = +"".b
          encoding = headers.fetch("content-encoding", []).join(",").strip.downcase
          @encoding = encoding.presence || "identity"
          @inflater = case @encoding
          when "identity" then nil
          when "gzip" then Zlib::Inflate.new(Zlib::MAX_WBITS + 16)
          when "deflate" then Zlib::Inflate.new
          else
            raise Error.new(
              reason_code: "unsupported_content_encoding",
              evidence: { content_encoding_supported: false }
            )
          end
        end

        def write(chunk)
          raise Error.new(reason_code: "canceled") if @cancellation.call == true

          @compressed_bytes += chunk.bytesize
          if @compressed_bytes > @limits.max_body_bytes
            raise Error.new(
              reason_code: "response_too_large",
              evidence: { compressed_byte_count: @compressed_bytes }
            )
          end
          if @inflater
            @inflater.inflate(chunk) { |decoded| emit(decoded) }
          else
            emit(chunk)
          end
        rescue Zlib::Error
          raise Error.new(reason_code: "malformed_response"), cause: nil
        end

        def finish
          @inflater.finish { |decoded| emit(decoded) } if @inflater
          {
            compressed_bytes: @compressed_bytes,
            decoded_bytes: @decoded_bytes,
            body_sha256: @digest.hexdigest,
            sniffed_kind: sniffed_kind
          }
        rescue Zlib::Error
          raise Error.new(reason_code: "malformed_response"), cause: nil
        ensure
          @inflater&.close
        end

        private

        def emit(chunk)
          return if chunk.empty?

          @decoded_bytes += chunk.bytesize
          if @decoded_bytes > @limits.max_decompressed_bytes
            raise Error.new(
              reason_code: "decompression_limit",
              evidence: { decoded_byte_count: @decoded_bytes }
            )
          end
          ratio = @decoded_bytes.fdiv([ @compressed_bytes, 1 ].max)
          if ratio > @limits.max_decompression_ratio
            raise Error.new(
              reason_code: "decompression_limit",
              evidence: {
                compressed_byte_count: @compressed_bytes,
                decoded_byte_count: @decoded_bytes
              }
            )
          end
          @sample << chunk.byteslice(0, SNIFF_BYTES - @sample.bytesize) if @sample.bytesize < SNIFF_BYTES
          @digest.update(chunk)
          offset = 0
          while offset < chunk.bytesize
            part = chunk.byteslice(offset, READ_CHUNK_BYTES)
            @sink.write(part)
            offset += part.bytesize
          end
        end

        def sniffed_kind
          return "empty" if @decoded_bytes.zero?

          sample = @sample.dup.force_encoding(Encoding::BINARY)
          stripped = sample.sub(/\A[\x00-\x20]+/n, "")
          lower = stripped.downcase
          return "html" if lower.start_with?("<!doctype html", "<html", "<head", "<body")
          return "xml" if lower.start_with?("<?xml", "<urlset", "<sitemapindex")
          return "json" if stripped.start_with?("{", "[")
          return "pdf" if sample.start_with?("%PDF-")
          return "image" if image_signature?(sample)
          return "binary" if binary?(sample)
          return "text" if sample.dup.force_encoding(Encoding::UTF_8).valid_encoding?

          "unknown"
        end

        def image_signature?(sample)
          sample.start_with?("\x89PNG\r\n\x1a\n".b, "GIF87a", "GIF89a", "\xff\xd8\xff".b) ||
            (sample.bytesize >= 12 && sample.byteslice(0, 4) == "RIFF" && sample.byteslice(8, 4) == "WEBP")
        end

        def binary?(sample)
          return true if sample.include?("\x00")

          controls = sample.bytes.count { |byte| byte < 9 || byte.between?(14, 31) }
          controls > sample.bytesize / 10
        end
      end
    end
  end
end
